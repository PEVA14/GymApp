import Foundation
import SwiftData

/// A workout you actually performed on a particular date.
///
/// A session is created by *copying* a template, not by referencing one. The
/// name is a snapshot; `templateID` is a dead UUID kept only so we can later ask
/// "which routine did this come from", and it is safe for that template to no
/// longer exist.
///
/// `endedAt == nil` means the workout is still in progress. The session is
/// written to the store the moment it starts, so an in-progress workout survives
/// the app being killed — and so a widget, Live Activity or watch app can read
/// it later without the workout living only in view state.
@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var name: String = ""
    var templateID: UUID?
    var startedAt: Date = Date()
    var endedAt: Date?
    var notes: String = ""

    /// When the current rest period ends, or `nil` if not resting.
    ///
    /// An *end date*, not a countdown. Storing "seconds remaining" and
    /// decrementing it would drift, stop while backgrounded, and be wrong after
    /// the phone locks. An instant is absolute: remaining time is always
    /// `restEndsAt - now`, however long the app was away. It is also exactly the
    /// shape ActivityKit wants for a Live Activity countdown.
    var restEndsAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []

    init(name: String, templateID: UUID? = nil, startedAt: Date = Date()) {
        self.id = UUID()
        self.name = name
        self.templateID = templateID
        self.startedAt = startedAt
    }

    var orderedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    var isInProgress: Bool { endedAt == nil }

    func isResting(at now: Date = Date()) -> Bool {
        guard let restEndsAt else { return false }
        return restEndsAt > now
    }

    /// Seconds left, clamped at zero so a finished timer never reads negative.
    func restRemaining(at now: Date = Date()) -> TimeInterval {
        guard let restEndsAt else { return 0 }
        return max(restEndsAt.timeIntervalSince(now), 0)
    }

    func startRest(seconds: Int, from now: Date = Date()) {
        guard seconds > 0 else { return }
        restEndsAt = now.addingTimeInterval(TimeInterval(seconds))
    }

    /// Add or remove time mid-rest. Shortening below the current moment ends the
    /// rest rather than leaving a timer stuck in the past.
    func adjustRest(by seconds: Int, from now: Date = Date()) {
        guard let restEndsAt else { return }
        let adjusted = restEndsAt.addingTimeInterval(TimeInterval(seconds))
        self.restEndsAt = adjusted > now ? adjusted : nil
    }

    func stopRest() {
        restEndsAt = nil
    }

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
}

extension WorkoutSession {
    /// Begins a workout by **copying** a routine.
    ///
    /// Everything is duplicated — the name, the exercise order, one blank
    /// `SetEntry` per target set. The returned session holds no reference back
    /// to the template, so editing or deleting that routine later cannot alter
    /// this workout.
    ///
    /// The session is inserted immediately with `endedAt == nil`, which is what
    /// makes an in-progress workout survive the app being killed.
    @discardableResult
    static func start(
        from template: WorkoutTemplate,
        in context: ModelContext,
        now: Date = Date()
    ) -> WorkoutSession {
        let session = WorkoutSession(name: template.name, templateID: template.id, startedAt: now)
        context.insert(session)

        for (index, entry) in template.orderedExercises.enumerated() {
            // An entry whose exercise was deleted is skipped rather than
            // copied as a nameless row.
            guard let exercise = entry.exercise else { continue }

            let performed = SessionExercise(exercise: exercise, sortOrder: index)
            context.insert(performed)
            performed.session = session

            for setIndex in 0..<max(entry.targetSets, 1) {
                let set = SetEntry(sortOrder: setIndex)
                context.insert(set)
                set.sessionExercise = performed
            }
        }

        return session
    }

    /// Ends the workout, discarding sets that were never completed.
    ///
    /// Because sets are pre-filled from the routine's target count, an unfinished
    /// row is normal — you planned four and did three. Keeping those would
    /// pollute history with 0 kg × 0 rep entries and skew every future stat.
    func finish(in context: ModelContext, now: Date = Date()) {
        for performed in orderedExercises {
            for set in performed.orderedSets where !set.isCompleted {
                context.delete(set)
            }
        }
        endedAt = now
    }
}

/// One exercise as performed within a session, holding the sets you logged.
///
/// It keeps a live link to `Exercise` (so renaming a movement updates all
/// history, and so per-exercise history queries work) plus a snapshot of the
/// name as a fallback if that exercise is ever deleted.
@Model
final class SessionExercise {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var exerciseName: String = ""

    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry]? = []

    init(exercise: Exercise, sortOrder: Int) {
        self.id = UUID()
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.sortOrder = sortOrder
    }

    var orderedSets: [SetEntry] {
        (sets ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Prefer the live exercise name so renames propagate through history; fall
    /// back to the snapshot if the exercise was deleted (`.nullify` clears the
    /// reference, which is exactly what `exerciseName` exists for).
    var displayName: String {
        exercise?.name ?? exerciseName
    }

    /// The last time this exercise was performed before this one.
    ///
    /// This is what progressive overload needs: what you lifted last session, so
    /// you can beat it. It walks the `Exercise.sessionEntries` relationship
    /// rather than running a fetch — which is the whole reason `SessionExercise`
    /// keeps a live link to `Exercise` instead of only a name snapshot.
    ///
    /// Unfinished and empty sessions are skipped, so an abandoned workout never
    /// becomes the thing you are trying to beat.
    var previousPerformance: SessionExercise? {
        guard let exercise, let startedAt = session?.startedAt else { return nil }

        return (exercise.sessionEntries ?? [])
            .filter { candidate in
                guard candidate.id != id, let other = candidate.session else { return false }
                return !other.isInProgress
                    && other.startedAt < startedAt
                    && candidate.orderedSets.contains(where: \.isCompleted)
            }
            .max { left, right in
                (left.session?.startedAt ?? .distantPast) < (right.session?.startedAt ?? .distantPast)
            }
    }

    /// Completed sets only — what you actually did, not what you planned.
    var completedSets: [SetEntry] {
        orderedSets.filter(\.isCompleted)
    }

    /// The best estimated 1RM ever achieved for this exercise *before* this
    /// session — the bar a set has to clear to count as a record.
    ///
    /// `nil` when there is no earlier history, in which case the first real set
    /// is not treated as a record. Every set being a PR on day one is noise.
    var previousBestOneRepMax: Double? {
        guard let exercise, let startedAt = session?.startedAt else { return nil }

        let earlier = (exercise.sessionEntries ?? [])
            .filter { candidate in
                guard candidate.id != id, let other = candidate.session else { return false }
                return !other.isInProgress && other.startedAt < startedAt
            }
            .flatMap(\.completedSets)
            .map(TrainingMath.estimatedOneRepMax(of:))

        return earlier.max()
    }

    /// Sets in this exercise that beat every previous performance.
    ///
    /// Uses a running best rather than a fixed threshold, so a session where you
    /// improve three times in a row flags three records, but three sets that all
    /// merely beat last month's number flag only the first. Estimated 1RM is the
    /// measure because it captures both more weight and more reps.
    func personalRecordSetIDs() -> Set<UUID> {
        guard var best = previousBestOneRepMax else { return [] }

        var records: Set<UUID> = []
        for set in completedSets {
            let oneRepMax = TrainingMath.estimatedOneRepMax(of: set)
            if oneRepMax > best {
                records.insert(set.id)
                best = oneRepMax
            }
        }
        return records
    }
}

/// A single set: a weight, a rep count, and whether you actually completed it.
///
/// Weight is **always** stored in kilograms. Display units are a presentation
/// concern applied at formatting time, never in the store.
@Model
final class SetEntry {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var weightKg: Double = 0
    var reps: Int = 0
    var isCompleted: Bool = false
    var completedAt: Date?
    /// Rate of Perceived Exertion. Reserved — not surfaced in the UI yet.
    var rpe: Double?

    var sessionExercise: SessionExercise?

    init(sortOrder: Int, weightKg: Double = 0, reps: Int = 0) {
        self.id = UUID()
        self.sortOrder = sortOrder
        self.weightKg = weightKg
        self.reps = reps
    }
}

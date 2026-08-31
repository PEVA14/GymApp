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

    var duration: TimeInterval {
        (endedAt ?? Date()).timeIntervalSince(startedAt)
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

import Foundation
import SwiftData

/// A movement in the exercise library, e.g. "Incline Dumbbell Press".
///
/// An `Exercise` is an *identity*, not a plan. Templates and past sessions both
/// point at it, which is what lets us answer "what did I lift for this exercise
/// last time?" across the whole history. Because of that we never hard-delete
/// exercises — we set `isArchived` instead, so old sessions keep their link.
@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var muscleGroupRaw: String = MuscleGroup.other.rawValue
    var notes: String = ""
    var isArchived: Bool = false
    var createdAt: Date = Date()

    /// Rows in workout templates that use this exercise.
    /// Deleting the exercise removes it from templates (`.cascade`) — a template
    /// row pointing at a nonexistent exercise would be meaningless.
    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.exercise)
    var templateEntries: [TemplateExercise]? = []

    /// Past performances of this exercise.
    /// Deleting the exercise must NOT delete history, so `.nullify` — the
    /// session rows survive and fall back to their stored `exerciseName`.
    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionEntries: [SessionExercise]? = []

    init(name: String, muscleGroup: MuscleGroup = .other, notes: String = "") {
        self.id = UUID()
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.notes = notes
        self.isArchived = false
        self.createdAt = Date()
    }

    /// Typed access to the raw stored string. Unrecognised values (e.g. written
    /// by a newer version of the app) degrade to `.other` rather than failing.
    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
        set { muscleGroupRaw = newValue.rawValue }
    }

    /// Every finished performance of this exercise, oldest first.
    ///
    /// Charts want ascending time. Unfinished sessions and exercises that were
    /// skipped (no completed sets) are excluded — plotting a zero for a workout
    /// where you never did the movement would read as a collapse in strength.
    var performanceHistory: [SessionExercise] {
        (sessionEntries ?? [])
            .filter { entry in
                guard let session = entry.session else { return false }
                return !session.isInProgress && !entry.completedSets.isEmpty
            }
            .sorted {
                ($0.session?.startedAt ?? .distantPast) < ($1.session?.startedAt ?? .distantPast)
            }
    }
}

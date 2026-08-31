import Foundation
import SwiftData

/// A reusable routine — "Push A", "Pull B". This is the *plan*.
///
/// Templates are mutable and expected to change over time. Nothing in your
/// workout history points back at a template, so editing or deleting one never
/// alters what you actually did.
@Model
final class WorkoutTemplate {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TemplateExercise.template)
    var exercises: [TemplateExercise]? = []

    init(name: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    /// SwiftData does not preserve array order, so ordering is explicit via
    /// `sortOrder`. Views should always read through this, never `exercises`.
    var orderedExercises: [TemplateExercise] {
        (exercises ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }
}

/// One line in a template: "Push A contains Incline Dumbbell Press, 3rd, 4 sets".
///
/// This exists as its own model because the position and target set count belong
/// to the *template*, not to the exercise — Incline Press can be 4 sets in Push A
/// and 3 sets in Push B.
@Model
final class TemplateExercise {
    var id: UUID = UUID()
    var sortOrder: Int = 0
    var targetSets: Int = 3

    var template: WorkoutTemplate?
    var exercise: Exercise?

    init(exercise: Exercise, sortOrder: Int, targetSets: Int = 3) {
        self.id = UUID()
        self.exercise = exercise
        self.sortOrder = sortOrder
        self.targetSets = targetSets
    }
}

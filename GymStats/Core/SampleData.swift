import Foundation
import SwiftData

/// An in-memory container populated with realistic data, for SwiftUI previews.
///
/// `isStoredInMemoryOnly: true` means nothing here touches the real database —
/// previews get a fresh throwaway store every time. Use it in a preview with:
///
///     #Preview {
///         SomeView()
///             .modelContainer(SampleData.previewContainer)
///     }
@MainActor
enum SampleData {
    static let previewContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetEntry.self,
            BodyMeasurement.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            populate(container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }()

    private static func populate(_ context: ModelContext) {
        // Exercise library
        let inclineDBPress = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        let latPulldown = Exercise(name: "Lat Pulldown", muscleGroup: .back)
        let squat = Exercise(name: "Barbell Back Squat", muscleGroup: .legs)
        let lateralRaise = Exercise(name: "Lateral Raise", muscleGroup: .shoulders)
        for exercise in [inclineDBPress, latPulldown, squat, lateralRaise] {
            context.insert(exercise)
        }

        // A template: Push A
        let pushA = WorkoutTemplate(name: "Push A", sortOrder: 0)
        context.insert(pushA)
        pushA.exercises = [
            TemplateExercise(exercise: inclineDBPress, sortOrder: 0, targetSets: 3),
            TemplateExercise(exercise: lateralRaise, sortOrder: 1, targetSets: 4),
        ]

        // A completed session from a week ago, matching the example in the brief:
        // 30 kg x 8, 30 kg x 7, 27.5 kg x 10
        let lastWeek = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        let session = WorkoutSession(name: "Push A", templateID: pushA.id, startedAt: lastWeek)
        session.endedAt = lastWeek.addingTimeInterval(65 * 60)
        context.insert(session)

        let performed = SessionExercise(exercise: inclineDBPress, sortOrder: 0)
        session.exercises = [performed]
        performed.sets = [
            completedSet(sortOrder: 0, weightKg: 30, reps: 8, at: lastWeek),
            completedSet(sortOrder: 1, weightKg: 30, reps: 7, at: lastWeek),
            completedSet(sortOrder: 2, weightKg: 27.5, reps: 10, at: lastWeek),
        ]

        // Body measurements spread over the last few weeks
        for weeksAgo in 0..<4 {
            let date = Date().addingTimeInterval(Double(-weeksAgo) * 7 * 24 * 60 * 60)
            context.insert(BodyMeasurement(type: .bodyWeight, value: 78.0 - Double(weeksAgo) * 0.4, date: date))
            context.insert(BodyMeasurement(type: .waist, value: 82.0 + Double(weeksAgo) * 0.5, date: date))
        }
    }

    private static func completedSet(sortOrder: Int, weightKg: Double, reps: Int, at date: Date) -> SetEntry {
        let set = SetEntry(sortOrder: sortOrder, weightKg: weightKg, reps: reps)
        set.isCompleted = true
        set.completedAt = date
        return set
    }
}

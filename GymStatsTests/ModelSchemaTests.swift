import Testing
import SwiftData
import Foundation
@testable import GymStats

/// These tests exist mainly to catch schema problems, which otherwise only show
/// up as a crash on launch. They also pin down the two rules the data model
/// depends on: history is independent of templates, and deleting an exercise
/// does not destroy history.
///
/// Serialized because a crash in any Swift Testing test brings down the whole
/// test process; running one at a time keeps a failure attributable.
@MainActor
@Suite(.serialized)
struct ModelSchemaTests {

    /// Held as a stored property for the lifetime of the test. A `ModelContext`
    /// does not keep its container alive, so `ModelContainer(...).mainContext`
    /// as a one-liner leaves the context pointing at a deallocated container
    /// and traps on first use.
    ///
    /// Swift Testing creates a fresh instance of the suite for every test, so
    /// each test gets its own empty in-memory store.
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetEntry.self,
            BodyMeasurement.self,
        ])
        container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }

    @Test func containerBuildsAndPersists() throws {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(bench)

        let fetched = try context.fetch(FetchDescriptor<Exercise>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.muscleGroup == .chest)
    }

    @Test func deletingTemplateLeavesHistoryIntact() throws {
        let press = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        context.insert(press)

        let template = WorkoutTemplate(name: "Push A")
        context.insert(template)
        template.exercises = [TemplateExercise(exercise: press, sortOrder: 0, targetSets: 3)]

        // A session copies the template rather than referencing it.
        let session = WorkoutSession(name: template.name, templateID: template.id)
        context.insert(session)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        session.exercises = [performed]
        performed.sets = [SetEntry(sortOrder: 0, weightKg: 30, reps: 8)]

        context.delete(template)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)
        #expect(sessions.first?.name == "Push A")
        #expect(sessions.first?.orderedExercises.first?.orderedSets.count == 1)
    }

    /// The guarantee that matters: even if an exercise is hard-deleted, the
    /// history row survives and still reads back with a usable name.
    @Test func deletingExerciseLeavesHistoryReadable() throws {
        let press = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        context.insert(press)

        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        session.exercises = [SessionExercise(exercise: press, sortOrder: 0)]
        try context.save()

        context.delete(press)
        try context.save()

        let performed = try context.fetch(FetchDescriptor<SessionExercise>())
        #expect(performed.count == 1)
        #expect(performed.first?.displayName == "Incline Dumbbell Press")
    }

    /// The path the app actually takes. Archiving hides an exercise from the
    /// library while leaving every relationship intact.
    @Test func archivingExerciseKeepsTheLiveLink() throws {
        let press = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        context.insert(press)

        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        session.exercises = [SessionExercise(exercise: press, sortOrder: 0)]
        try context.save()

        press.isArchived = true
        press.name = "Incline DB Press"   // renames propagate through history
        try context.save()

        let performed = try context.fetch(FetchDescriptor<SessionExercise>()).first
        #expect(performed?.exercise != nil)
        #expect(performed?.displayName == "Incline DB Press")
    }

    @Test func measurementTypeRoundTripsThroughRawValue() throws {
        let waist = BodyMeasurement(type: .waist, value: 82.5)
        context.insert(waist)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BodyMeasurement>()).first
        #expect(fetched?.type == .waist)
        #expect(fetched?.value == 82.5)
    }

    @Test func weightUnitConversionRoundTrips() {
        let kg = 102.5
        let pounds = WeightUnit.pounds.fromKilograms(kg)
        #expect(abs(WeightUnit.pounds.toKilograms(pounds) - kg) < 0.0001)
        #expect(abs(pounds - 225.97) < 0.01)
    }
}

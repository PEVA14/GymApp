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

    @Test func startingWorkoutCopiesTemplateAndPreFillsSets() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        let raise = Exercise(name: "Lateral Raise", muscleGroup: .shoulders)
        context.insert(press)
        context.insert(raise)

        let template = WorkoutTemplate(name: "Push A")
        context.insert(template)
        template.exercises = [
            TemplateExercise(exercise: press, sortOrder: 0, targetSets: 4),
            TemplateExercise(exercise: raise, sortOrder: 1, targetSets: 3),
        ]

        let session = WorkoutSession.start(from: template, in: context)
        try context.save()

        #expect(session.name == "Push A")
        #expect(session.isInProgress)
        #expect(session.orderedExercises.count == 2)
        // Order is preserved, and sets are pre-filled from targetSets.
        #expect(session.orderedExercises[0].displayName == "Bench Press")
        #expect(session.orderedExercises[0].orderedSets.count == 4)
        #expect(session.orderedExercises[1].orderedSets.count == 3)

        // Renaming the routine afterwards must not touch the session.
        template.name = "Push B"
        try context.save()
        #expect(session.name == "Push A")
    }

    @Test func finishingWorkoutDropsIncompleteSets() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        let template = WorkoutTemplate(name: "Push A")
        context.insert(template)
        template.exercises = [TemplateExercise(exercise: press, sortOrder: 0, targetSets: 4)]

        let session = WorkoutSession.start(from: template, in: context)

        // Completed three of the four planned sets.
        for set in session.orderedExercises[0].orderedSets.prefix(3) {
            set.weightKg = 60
            set.reps = 8
            set.isCompleted = true
        }

        session.finish(in: context)
        try context.save()

        #expect(!session.isInProgress)
        #expect(session.endedAt != nil)
        #expect(session.orderedExercises[0].orderedSets.count == 3)
        #expect(session.orderedExercises[0].orderedSets.allSatisfy { $0.isCompleted })
    }

    @Test func measurementTypeRoundTripsThroughRawValue() throws {
        let waist = BodyMeasurement(type: .waist, value: 82.5)
        context.insert(waist)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<BodyMeasurement>()).first
        #expect(fetched?.type == .waist)
        #expect(fetched?.value == 82.5)
    }

    /// Volume counts only completed sets — a pre-filled row you never did must
    /// not contribute, even if it somehow holds numbers.
    @Test func volumeIgnoresIncompleteSets() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        session.exercises = [performed]

        let done = SetEntry(sortOrder: 0, weightKg: 60, reps: 10)   // 600
        done.isCompleted = true
        let alsoDone = SetEntry(sortOrder: 1, weightKg: 27.5, reps: 8) // 220
        alsoDone.isCompleted = true
        let skipped = SetEntry(sortOrder: 2, weightKg: 100, reps: 10)  // ignored
        performed.sets = [done, alsoDone, skipped]
        try context.save()

        #expect(TrainingMath.volume(of: session) == 820)
        #expect(TrainingMath.completedSetCount(of: session) == 2)
    }

    /// Progressive overload depends on this picking the *most recent finished*
    /// performance — not the oldest, not an abandoned workout, not itself.
    @Test func previousPerformanceFindsMostRecentFinishedSession() throws {
        let press = Exercise(name: "Incline Dumbbell Press", muscleGroup: .chest)
        context.insert(press)

        func makeSession(daysAgo: Int, weight: Double, finished: Bool) -> SessionExercise {
            let date = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
            let session = WorkoutSession(name: "Push A", startedAt: date)
            context.insert(session)
            if finished { session.endedAt = date.addingTimeInterval(3600) }

            let performed = SessionExercise(exercise: press, sortOrder: 0)
            session.exercises = [performed]
            let set = SetEntry(sortOrder: 0, weightKg: weight, reps: 8)
            set.isCompleted = true
            performed.sets = [set]
            return performed
        }

        _ = makeSession(daysAgo: 21, weight: 25, finished: true)   // older
        _ = makeSession(daysAgo: 7, weight: 30, finished: true)    // the answer
        _ = makeSession(daysAgo: 2, weight: 99, finished: false)   // abandoned, must be ignored

        // Today's workout, still in progress.
        let today = WorkoutSession(name: "Push A")
        context.insert(today)
        let current = SessionExercise(exercise: press, sortOrder: 0)
        today.exercises = [current]
        current.sets = [SetEntry(sortOrder: 0)]
        try context.save()

        let previous = current.previousPerformance
        #expect(previous != nil)
        #expect(previous?.completedSets.first?.weightKg == 30)
        // And it never returns itself.
        #expect(previous?.id != current.id)
    }

    @Test func previousPerformanceIsNilOnFirstEverSession() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        session.exercises = [performed]
        try context.save()

        #expect(performed.previousPerformance == nil)
    }

    /// The narrow measurement design: adding a type must never need a schema
    /// change, and each type's history must be independently queryable.
    @Test func measurementsAreIndependentPerType() throws {
        let now = Date()
        context.insert(BodyMeasurement(type: .bodyWeight, value: 78.4, date: now))
        context.insert(BodyMeasurement(type: .bodyWeight, value: 78.0, date: now.addingTimeInterval(86_400)))
        context.insert(BodyMeasurement(type: .waist, value: 82.5, date: now))
        try context.save()

        let all = try context.fetch(
            FetchDescriptor<BodyMeasurement>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        )
        let bodyWeights = all.filter { $0.type == .bodyWeight }
        #expect(bodyWeights.count == 2)
        #expect(bodyWeights.first?.value == 78.0)   // newest first
        #expect(all.filter { $0.type == .waist }.count == 1)
    }

    @Test func measurementUnitsFollowDimension() {
        #expect(MeasurementType.bodyWeight.canonicalUnitSymbol == "kg")
        #expect(MeasurementType.waist.canonicalUnitSymbol == "cm")
        #expect(MeasurementType.thigh.dimension == .length)
    }

    @Test func estimatedOneRepMaxUsesEpley() {
        #expect(TrainingMath.estimatedOneRepMax(weightKg: 100, reps: 1) == 100)
        // 60 × (1 + 10/30) = 80
        #expect(abs(TrainingMath.estimatedOneRepMax(weightKg: 60, reps: 10) - 80) < 0.0001)
        #expect(TrainingMath.estimatedOneRepMax(weightKg: 0, reps: 5) == 0)
        #expect(TrainingMath.estimatedOneRepMax(weightKg: 50, reps: 0) == 0)
    }

    /// A record must beat all earlier history, and within one session only the
    /// sets that actually improve on the running best should be flagged.
    @Test func personalRecordsBeatHistoryAndRunningBest() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        // Last month: 60 × 8  →  e1RM 76
        let old = WorkoutSession(name: "Push A", startedAt: Date().addingTimeInterval(-30 * 86_400))
        context.insert(old)
        old.endedAt = old.startedAt.addingTimeInterval(3600)
        let oldPerformed = SessionExercise(exercise: press, sortOrder: 0)
        old.exercises = [oldPerformed]
        let oldSet = SetEntry(sortOrder: 0, weightKg: 60, reps: 8)
        oldSet.isCompleted = true
        oldPerformed.sets = [oldSet]

        // Today.
        let today = WorkoutSession(name: "Push A")
        context.insert(today)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        today.exercises = [performed]

        let below = SetEntry(sortOrder: 0, weightKg: 60, reps: 6)    // 72 — no
        let first = SetEntry(sortOrder: 1, weightKg: 60, reps: 9)    // 78 — PR
        let equalish = SetEntry(sortOrder: 2, weightKg: 60, reps: 9) // 78 — not again
        let better = SetEntry(sortOrder: 3, weightKg: 65, reps: 9)   // 84.5 — PR
        for set in [below, first, equalish, better] { set.isCompleted = true }
        performed.sets = [below, first, equalish, better]
        try context.save()

        let records = performed.personalRecordSetIDs()
        #expect(records == [first.id, better.id])
    }

    /// Day one should not be a wall of PR badges.
    @Test func firstEverSessionHasNoRecords() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        session.exercises = [performed]
        let set = SetEntry(sortOrder: 0, weightKg: 100, reps: 10)
        set.isCompleted = true
        performed.sets = [set]
        try context.save()

        #expect(performed.previousBestOneRepMax == nil)
        #expect(performed.personalRecordSetIDs().isEmpty)
    }

    /// Progress charts need ascending time, finished sessions only, and no
    /// zero-valued points for workouts where the exercise was skipped.
    @Test func performanceHistoryIsOldestFirstAndExcludesSkipped() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)

        func add(daysAgo: Int, weight: Double, completed: Bool, finished: Bool = true) {
            let date = Date().addingTimeInterval(Double(-daysAgo) * 86_400)
            let session = WorkoutSession(name: "Push A", startedAt: date)
            context.insert(session)
            if finished { session.endedAt = date.addingTimeInterval(3600) }
            let performed = SessionExercise(exercise: press, sortOrder: 0)
            session.exercises = [performed]
            let set = SetEntry(sortOrder: 0, weightKg: weight, reps: 5)
            set.isCompleted = completed
            performed.sets = [set]
        }

        add(daysAgo: 20, weight: 60, completed: true)
        add(daysAgo: 10, weight: 65, completed: true)
        add(daysAgo: 5, weight: 70, completed: false)              // skipped
        add(daysAgo: 1, weight: 99, completed: true, finished: false) // in progress
        try context.save()

        let history = press.performanceHistory
        #expect(history.count == 2)
        #expect(TrainingMath.topSetWeight(of: history[0]) == 60)   // oldest first
        #expect(TrainingMath.topSetWeight(of: history[1]) == 65)
    }

    @Test func progressMetricsReadFromCompletedSets() throws {
        let press = Exercise(name: "Bench Press", muscleGroup: .chest)
        context.insert(press)
        let session = WorkoutSession(name: "Push A")
        context.insert(session)
        let performed = SessionExercise(exercise: press, sortOrder: 0)
        session.exercises = [performed]

        let a = SetEntry(sortOrder: 0, weightKg: 60, reps: 10)  // e1RM 80, vol 600
        let b = SetEntry(sortOrder: 1, weightKg: 70, reps: 3)   // e1RM 77, vol 210
        for set in [a, b] { set.isCompleted = true }
        performed.sets = [a, b]
        try context.save()

        #expect(ProgressMetric.topWeight.value(for: performed) == 70)
        #expect(abs(ProgressMetric.oneRepMax.value(for: performed) - 80) < 0.0001)
        #expect(ProgressMetric.volume.value(for: performed) == 810)
    }

    /// The timer is an end date, not a countdown, so "how long is left" must be
    /// correct for any `now` — including one long after the app was backgrounded.
    @Test func restTimerIsComputedFromAnEndDate() {
        let session = WorkoutSession(name: "Push A")
        let start = Date()

        #expect(!session.isResting(at: start))
        #expect(session.restRemaining(at: start) == 0)

        session.startRest(seconds: 90, from: start)
        #expect(session.isResting(at: start))
        #expect(session.restRemaining(at: start) == 90)

        // 30s later — as if the app had been backgrounded throughout.
        let later = start.addingTimeInterval(30)
        #expect(session.restRemaining(at: later) == 60)

        // Past the end it reads zero, never negative.
        let after = start.addingTimeInterval(200)
        #expect(!session.isResting(at: after))
        #expect(session.restRemaining(at: after) == 0)
    }

    @Test func restAdjustmentsClampAndCancel() {
        let session = WorkoutSession(name: "Push A")
        let start = Date()
        session.startRest(seconds: 60, from: start)

        session.adjustRest(by: 15, from: start)
        #expect(session.restRemaining(at: start) == 75)

        session.adjustRest(by: -15, from: start)
        #expect(session.restRemaining(at: start) == 60)

        // Removing more time than remains ends the rest rather than leaving an
        // end date stuck in the past.
        session.adjustRest(by: -120, from: start)
        #expect(session.restEndsAt == nil)
        #expect(!session.isResting(at: start))
    }

    @Test func restTimerOffDoesNotStart() {
        let session = WorkoutSession(name: "Push A")
        session.startRest(seconds: 0)
        #expect(session.restEndsAt == nil)
    }

    @Test func countdownFormatting() {
        #expect(Formatters.countdown(90) == "1:30")
        #expect(Formatters.countdown(7) == "0:07")
        #expect(Formatters.countdown(0) == "0:00")
        #expect(Formatters.countdown(-5) == "0:00")
    }

    @Test func weightFormattingDropsTrailingZeros() {
        #expect(Formatters.weight(30) == "30")
        #expect(Formatters.weight(27.5) == "27.5")
    }

    /// The point of the whole unit layer: changing the display unit must never
    /// change what is stored, and typing in pounds must land as kilograms.
    @Test func unitSettingsConvertAtTheEdgesOnly() {
        let metric = UnitSettings(weight: .kilograms, length: .centimetres)
        let imperial = UnitSettings(weight: .pounds, length: .inches)

        // Same stored value, two renderings.
        #expect(metric.weightString(fromKilograms: 100) == "100")
        #expect(imperial.weightString(fromKilograms: 100) == "220.5")
        #expect(metric.weightSymbol == "kg")
        #expect(imperial.weightSymbol == "lb")

        // Input in pounds is stored in kilograms.
        let stored = imperial.kilograms(fromDisplayed: 220.46226218)
        #expect(abs(stored - 100) < 0.0001)

        // Body weight follows the weight unit, lengths the length unit.
        #expect(imperial.symbol(for: .bodyWeight) == "lb")
        #expect(imperial.symbol(for: .waist) == "in")
        #expect(abs(imperial.value(100, for: .waist) - 39.3700787) < 0.0001)
        #expect(abs(imperial.canonicalValue(39.3700787, for: .waist) - 100) < 0.0001)

        // Volume is a mass quantity, so it converts like any other load.
        #expect(imperial.volumeWithSymbol(fromKilograms: 100) == "220.5 lb")
    }

    @Test func weightUnitConversionRoundTrips() {
        let kg = 102.5
        let pounds = WeightUnit.pounds.fromKilograms(kg)
        #expect(abs(WeightUnit.pounds.toKilograms(pounds) - kg) < 0.0001)
        #expect(abs(pounds - 225.97) < 0.01)
    }
}

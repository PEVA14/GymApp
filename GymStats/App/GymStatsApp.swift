//
//  GymStatsApp.swift
//  GymStats
//

import SwiftUI
import SwiftData

@main
struct GymStatsApp: App {
    /// The single SwiftData container for the whole app. Creating it here and
    /// injecting it with `.modelContainer` puts a `ModelContext` into the
    /// SwiftUI environment, which is what `@Query` and
    /// `@Environment(\.modelContext)` read from in every view below.
    let modelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            TemplateExercise.self,
            WorkoutSession.self,
            SessionExercise.self,
            SetEntry.self,
            BodyMeasurement.self,
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

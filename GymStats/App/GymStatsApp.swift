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
        let configuration = ModelConfiguration(schema: schema, url: storeURL)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// SwiftData's default store lives at
    /// `Library/Application Support/default.store` — but iOS does **not** create
    /// `Application Support` for you. On a fresh install on a real device the
    /// directory is missing, so the store fails to open with ENOENT
    /// ("Failed to create file; code = 2"). Core Data then "recovers" into a
    /// store that never persists, so inserts silently vanish.
    ///
    /// The simulator usually has the directory already, which is why this only
    /// showed up on device. Creating it first makes the location deterministic
    /// on both.
    ///
    /// The filename stays `default.store` so any existing store is still found.
    private static var storeURL: URL {
        let directory = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory.appending(path: "default.store")
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}

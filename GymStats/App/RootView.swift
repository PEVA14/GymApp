import SwiftUI

/// The app shell: three tabs, matching the three things the app does.
/// Each tab's real content arrives in the steps that follow.
struct RootView: View {
    var body: some View {
        TabView {
            // For now the Train tab is the exercise library. In step 3 it
            // becomes the routine list, and the library moves behind a
            // toolbar button there.
            Tab("Train", systemImage: "dumbbell.fill") {
                NavigationStack {
                    ExerciseLibraryView()
                }
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                PlaceholderView(title: "History", detail: "Past workout sessions")
            }
            Tab("Body", systemImage: "figure.arms.open") {
                PlaceholderView(title: "Body", detail: "Measurements over time")
            }
        }
    }
}

private struct PlaceholderView: View {
    let title: String
    let detail: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: "hammer.fill", description: Text(detail))
                .navigationTitle(title)
        }
    }
}

#Preview {
    RootView()
}

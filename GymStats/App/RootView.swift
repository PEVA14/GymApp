import SwiftUI

/// The app shell: three tabs, matching the three things the app does.
/// Each tab's real content arrives in the steps that follow.
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Train", systemImage: "dumbbell.fill") {
                PlaceholderView(title: "Train", detail: "Routines and active workouts")
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

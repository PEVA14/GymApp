import SwiftUI
import SwiftData

/// The app shell: three tabs, matching the three things the app does.
struct RootView: View {
    var body: some View {
        TabView {
            // TemplateListView owns its own NavigationStack so it can push
            // straight to the editor after creating a routine.
            Tab("Train", systemImage: "dumbbell.fill") {
                TemplateListView()
            }
            Tab("History", systemImage: "clock.arrow.circlepath") {
                SessionListView()
            }
            Tab("Body", systemImage: "figure.arms.open") {
                MeasurementListView()
            }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(SampleData.previewContainer)
}

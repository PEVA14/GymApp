import SwiftUI
import SwiftData

/// Destinations in the Train tab that are not represented by a model object.
enum TrainRoute: Hashable {
    case exerciseLibrary
}

/// The routine list — "Push A", "Pull A", "Legs A"… This is the Train tab.
///
/// Templates are plans, so deleting one is safe: no workout session references a
/// template, they only ever copied from it. Past workouts are unaffected.
struct TemplateListView: View {
    @Query(sort: \WorkoutTemplate.sortOrder) private var templates: [WorkoutTemplate]

    /// An unfinished workout, if one exists. Because a session is written to the
    /// store the moment it starts, this survives the app being killed — which is
    /// what turns "resume workout" into a query rather than saved UI state.
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var unfinishedSessions: [WorkoutSession]

    @Environment(\.modelContext) private var modelContext

    /// Owning the navigation path lets us push straight to the editor after
    /// creating a routine.
    @State private var path = NavigationPath()
    @State private var activeSession: WorkoutSession?
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let unfinished = unfinishedSessions.first {
                    Section {
                        Button {
                            activeSession = unfinished
                        } label: {
                            LabeledContent {
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                            } label: {
                                Text("Resume \(unfinished.name)")
                                Text("In progress")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                ForEach(templates) { template in
                    HStack {
                        Button {
                            start(template)
                        } label: {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Start \(template.name)")

                        NavigationLink(value: template) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name)
                                Text(exerciseCountText(for: template))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteTemplates)
                .onMove(perform: moveTemplates)
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(session: session)
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView()
            }
            .navigationTitle("Routines")
            .overlay { emptyStateIfNeeded }
            .navigationDestination(for: WorkoutTemplate.self) { template in
                TemplateEditorView(template: template)
            }
            // Every destination in this stack is registered here at the root and
            // pushed by value. When a NavigationStack has a `path` binding,
            // mixing in closure-based NavigationLinks breaks navigation: the
            // closure push is not on the path, so a value-based push from inside
            // it has nothing to append to and silently does nothing.
            .navigationDestination(for: TrainRoute.self) { route in
                switch route {
                case .exerciseLibrary: ExerciseLibraryView()
                }
            }
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Routine", systemImage: "plus", action: createTemplate)
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink(value: TrainRoute.exerciseLibrary) {
                        Label("Exercises", systemImage: "list.bullet")
                    }
                }
                ToolbarItem(placement: .secondaryAction) {
                    EditButton()
                }
                ToolbarItem(placement: .secondaryAction) {
                    Button("Settings", systemImage: "gear") { isShowingSettings = true }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if templates.isEmpty {
            ContentUnavailableView(
                "No Routines",
                systemImage: "list.clipboard",
                description: Text("Create a routine like “Push A”, then add exercises to it.")
            )
        }
    }

    private func exerciseCountText(for template: WorkoutTemplate) -> String {
        let count = template.orderedExercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }

    private func start(_ template: WorkoutTemplate) {
        // Only one workout at a time: resume the existing one rather than
        // starting a second, which would make "the active workout" ambiguous
        // for the Live Activity and watch app later.
        if let unfinished = unfinishedSessions.first {
            activeSession = unfinished
            return
        }
        activeSession = WorkoutSession.start(from: template, in: modelContext)
    }

    private func createTemplate() {
        let template = WorkoutTemplate(name: "New Routine", sortOrder: templates.count)
        modelContext.insert(template)
        // Push straight into the editor so the placeholder name can be replaced
        // immediately.
        path.append(template)
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }

    /// SwiftData does not store array order, so reordering means rewriting the
    /// `sortOrder` of every row to match its new index.
    private func moveTemplates(from source: IndexSet, to destination: Int) {
        var reordered = templates
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, template) in reordered.enumerated() {
            template.sortOrder = index
        }
    }
}

#Preview {
    TemplateListView()
        .modelContainer(SampleData.previewContainer)
}

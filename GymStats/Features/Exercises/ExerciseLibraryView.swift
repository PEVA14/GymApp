import SwiftUI
import SwiftData

/// The exercise library: every movement you can put into a routine.
///
/// Exercises are archived rather than deleted, because workout history holds a
/// live reference to them. Archiving hides an exercise from the library while
/// leaving all past sessions intact.
struct ExerciseLibraryView: View {
    /// `@Query` fetches from SwiftData and keeps this view in sync — insert or
    /// change an Exercise anywhere in the app and this list re-renders itself.
    /// No manual reloading, no observers.
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    /// The context is how we write. It comes from the `.modelContainer(...)`
    /// applied in GymStatsApp.
    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var showArchived = false
    @State private var isCreatingExercise = false

    /// Muscle groups to show. Empty means "no filter", not "show nothing" —
    /// that way the default state needs no special-casing when the set of
    /// groups changes.
    @State private var selectedGroups: Set<MuscleGroup> = []

    var body: some View {
        // The filter bar is a sibling of the List, not a `safeAreaInset` on it.
        // An inset's background is drawn over the navigation bar's large title
        // and search field, which hid both. As a sibling it simply occupies the
        // space above the list.
        VStack(spacing: 0) {
            MuscleGroupFilterBar(groups: offeredGroups, selection: $selectedGroups)

            List {
                ForEach(groupedExercises, id: \.group) { section in
                    Section(section.group.displayName) {
                        ForEach(section.exercises) { exercise in
                            NavigationLink(value: exercise) {
                                row(for: exercise)
                            }
                            .swipeActions(edge: .trailing) {
                                if exercise.isArchived {
                                    Button("Unarchive", systemImage: "tray.and.arrow.up") {
                                        exercise.isArchived = false
                                    }
                                    .tint(.blue)
                                } else {
                                    Button("Archive", systemImage: "archivebox") {
                                        exercise.isArchived = true
                                    }
                                    .tint(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .overlay { emptyStateIfNeeded }
        }
        .navigationTitle("Exercises")
        .searchable(text: $searchText, prompt: "Search exercises")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Exercise", systemImage: "plus") {
                    isCreatingExercise = true
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Toggle("Show Archived", systemImage: "archivebox", isOn: $showArchived)
            }
        }
        .sheet(isPresented: $isCreatingExercise) {
            ExerciseEditorView(exercise: nil)
        }
    }

    private func row(for exercise: Exercise) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .foregroundStyle(.primary)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if exercise.isArchived {
                Text("Archived")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if groupedExercises.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else if !selectedGroups.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("No exercises in the selected muscle groups.")
                )
            } else {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "dumbbell",
                    description: Text("Add the movements you train, then build routines from them.")
                )
            }
        }
    }

    /// Which chips the filter bar offers: the groups you actually have
    /// exercises in, so the bar does not list ten empty categories. A group
    /// that is currently selected stays offered even if the search text hides
    /// its last exercise — otherwise the chip would vanish mid-filter and
    /// leave no way to switch it off.
    private var offeredGroups: [MuscleGroup] {
        let present = Set(visibleExercises(applyingGroupFilter: false).map(\.muscleGroup))
        return MuscleGroup.allCases.filter { present.contains($0) || selectedGroups.contains($0) }
    }

    /// Filtering and grouping happen in memory rather than in the `@Query`
    /// predicate. A dynamic predicate requires building the `Query` in an
    /// initialiser, and with a personal library of at most a few hundred
    /// exercises that complexity buys nothing.
    private func visibleExercises(applyingGroupFilter: Bool) -> [Exercise] {
        exercises.filter { exercise in
            guard showArchived || !exercise.isArchived else { return false }
            if applyingGroupFilter, !selectedGroups.isEmpty,
               !selectedGroups.contains(exercise.muscleGroup) { return false }
            guard !searchText.isEmpty else { return true }
            return exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedExercises: [(group: MuscleGroup, exercises: [Exercise])] {
        Dictionary(grouping: visibleExercises(applyingGroupFilter: true), by: \.muscleGroup)
            .map { (group: $0.key, exercises: $0.value) }
            .sorted { $0.group.displayName < $1.group.displayName }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
            // Supplied by TemplateListView in the real app; the preview has to
            // register it itself.
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
    }
    .modelContainer(SampleData.previewContainer)
}

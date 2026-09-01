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
    @State private var exerciseBeingEdited: Exercise?
    @State private var isCreatingExercise = false

    var body: some View {
        List {
            ForEach(groupedExercises, id: \.group) { section in
                Section(section.group.displayName) {
                    ForEach(section.exercises) { exercise in
                        Button {
                            exerciseBeingEdited = exercise
                        } label: {
                            row(for: exercise)
                        }
                        .buttonStyle(.plain)
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
        .navigationTitle("Exercises")
        .searchable(text: $searchText, prompt: "Search exercises")
        .overlay { emptyStateIfNeeded }
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
        .sheet(item: $exerciseBeingEdited) { exercise in
            ExerciseEditorView(exercise: exercise)
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
            if searchText.isEmpty {
                ContentUnavailableView(
                    "No Exercises",
                    systemImage: "dumbbell",
                    description: Text("Add the movements you train, then build routines from them.")
                )
            } else {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    /// Filtering and grouping happen in memory rather than in the `@Query`
    /// predicate. A dynamic predicate requires building the `Query` in an
    /// initialiser, and with a personal library of at most a few hundred
    /// exercises that complexity buys nothing.
    private var groupedExercises: [(group: MuscleGroup, exercises: [Exercise])] {
        let visible = exercises.filter { exercise in
            guard showArchived || !exercise.isArchived else { return false }
            guard !searchText.isEmpty else { return true }
            return exercise.name.localizedCaseInsensitiveContains(searchText)
        }

        return Dictionary(grouping: visible, by: \.muscleGroup)
            .map { (group: $0.key, exercises: $0.value) }
            .sorted { $0.group.displayName < $1.group.displayName }
    }
}

#Preview {
    NavigationStack {
        ExerciseLibraryView()
    }
    .modelContainer(SampleData.previewContainer)
}

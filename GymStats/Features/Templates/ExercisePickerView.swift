import SwiftUI
import SwiftData

/// Multi-select picker for adding exercises to a routine.
///
/// Multi-select rather than tap-one-and-close, because building a routine means
/// adding six or seven movements at once.
struct ExercisePickerView: View {
    /// Exercises already in the routine — hidden, so a routine cannot end up
    /// with the same movement twice.
    let excluding: Set<UUID>
    let onAdd: ([Exercise]) -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                ForEach(availableExercises) { exercise in
                    Button {
                        toggle(exercise)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .foregroundStyle(.primary)
                                Text(exercise.muscleGroup.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if selectedIDs.contains(exercise.id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Add Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .overlay { emptyStateIfNeeded }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add\(selectedIDs.isEmpty ? "" : " (\(selectedIDs.count))")") {
                        onAdd(availableExercises.filter { selectedIDs.contains($0.id) })
                        dismiss()
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if availableExercises.isEmpty {
            if !searchText.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                ContentUnavailableView(
                    "Nothing to Add",
                    systemImage: "dumbbell",
                    description: Text("Every exercise in your library is already in this routine.")
                )
            }
        }
    }

    /// Archived exercises are excluded — they should not appear in new routines,
    /// though existing routines that already use them keep working.
    private var availableExercises: [Exercise] {
        exercises.filter { exercise in
            guard !exercise.isArchived, !excluding.contains(exercise.id) else { return false }
            guard !searchText.isEmpty else { return true }
            return exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func toggle(_ exercise: Exercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else {
            selectedIDs.insert(exercise.id)
        }
    }
}

#Preview {
    ExercisePickerView(excluding: []) { _ in }
        .modelContainer(SampleData.previewContainer)
}

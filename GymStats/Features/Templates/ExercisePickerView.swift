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
    /// When false the picker chooses exactly one exercise — used for switching
    /// an exercise mid-workout, where "Add (2)" would be meaningless.
    var allowsMultipleSelection: Bool = true
    var confirmTitle: String = "Add"
    var title: String = "Add Exercises"
    let onAdd: ([Exercise]) -> Void

    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var selectedIDs: Set<UUID> = []

    /// Muscle groups to show. Empty means "no filter".
    @State private var selectedGroups: Set<MuscleGroup> = []

    var body: some View {
        NavigationStack {
            // A sibling of the List rather than a `safeAreaInset` on it — an
            // inset's background is drawn over the navigation bar's own
            // content. See ExerciseLibraryView.
            VStack(spacing: 0) {
                MuscleGroupFilterBar(groups: offeredGroups, selection: $selectedGroups)

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
                .overlay { emptyStateIfNeeded }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmLabel) {
                        onAdd(selectedExercises)
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
            } else if !selectedGroups.isEmpty {
                ContentUnavailableView(
                    "No Matches",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Nothing to add in the selected muscle groups.")
                )
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
    private func addableExercises(applyingGroupFilter: Bool) -> [Exercise] {
        exercises.filter { exercise in
            guard !exercise.isArchived, !excluding.contains(exercise.id) else { return false }
            if applyingGroupFilter, !selectedGroups.isEmpty,
               !selectedGroups.contains(exercise.muscleGroup) { return false }
            guard !searchText.isEmpty else { return true }
            return exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var availableExercises: [Exercise] {
        addableExercises(applyingGroupFilter: true)
    }

    /// Only groups you can actually add from, so the bar does not list empty
    /// categories. A selected group stays offered even once the search hides
    /// its last exercise, or the chip would vanish with no way to switch it off.
    private var offeredGroups: [MuscleGroup] {
        let present = Set(addableExercises(applyingGroupFilter: false).map(\.muscleGroup))
        return MuscleGroup.allCases.filter { present.contains($0) || selectedGroups.contains($0) }
    }

    /// Resolved against the whole library, not the filtered list: an exercise
    /// you ticked under "Chest" must survive switching the filter to "Back".
    /// Reading the visible list here would silently drop it on Add.
    private var selectedExercises: [Exercise] {
        exercises.filter { selectedIDs.contains($0.id) }
    }

    private var confirmLabel: String {
        guard allowsMultipleSelection, selectedIDs.count > 1 else { return confirmTitle }
        return "\(confirmTitle) (\(selectedIDs.count))"
    }

    private func toggle(_ exercise: Exercise) {
        if selectedIDs.contains(exercise.id) {
            selectedIDs.remove(exercise.id)
        } else if allowsMultipleSelection {
            selectedIDs.insert(exercise.id)
        } else {
            // Single selection: picking one replaces the other.
            selectedIDs = [exercise.id]
        }
    }
}

#Preview {
    ExercisePickerView(excluding: []) { _ in }
        .modelContainer(SampleData.previewContainer)
}

import SwiftUI
import SwiftData

/// Creates a new exercise, or edits an existing one.
///
/// One view handles both cases: `exercise == nil` means "create". The
/// alternative — two near-identical views — would duplicate the form and the
/// validation for no benefit.
struct ExerciseEditorView: View {
    /// `nil` when creating.
    let exercise: Exercise?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Used only to check for duplicate names, since SwiftData cannot enforce a
    /// unique constraint (CloudKit does not support them).
    @Query private var allExercises: [Exercise]

    /// Edits are held in local `@State` and only written to the model on Save,
    /// so backing out with Cancel leaves the stored exercise untouched.
    @State private var name = ""
    @State private var muscleGroup: MuscleGroup = .other
    @State private var notes = ""

    private var isEditing: Bool { exercise != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)

                    Picker("Muscle Group", selection: $muscleGroup) {
                        ForEach(MuscleGroup.allCases) { group in
                            Text(group.displayName).tag(group)
                        }
                    }
                } footer: {
                    if isDuplicateName {
                        Text("An exercise called “\(trimmedName)” already exists.")
                            .foregroundStyle(.red)
                    }
                }

                Section("Notes") {
                    TextField("Setup, cues, machine number…", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadExistingValues)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isDuplicateName: Bool {
        guard !trimmedName.isEmpty else { return false }
        return allExercises.contains { candidate in
            candidate.id != exercise?.id
                && candidate.name.localizedCaseInsensitiveCompare(trimmedName) == .orderedSame
        }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isDuplicateName
    }

    private func loadExistingValues() {
        guard let exercise else { return }
        name = exercise.name
        muscleGroup = exercise.muscleGroup
        notes = exercise.notes
    }

    private func save() {
        if let exercise {
            exercise.name = trimmedName
            exercise.muscleGroup = muscleGroup
            exercise.notes = notes
        } else {
            // `insert` is all that is needed — SwiftData autosaves, so there is
            // no explicit save() call anywhere in this app.
            modelContext.insert(
                Exercise(name: trimmedName, muscleGroup: muscleGroup, notes: notes)
            )
        }
        dismiss()
    }
}

#Preview("New") {
    ExerciseEditorView(exercise: nil)
        .modelContainer(SampleData.previewContainer)
}

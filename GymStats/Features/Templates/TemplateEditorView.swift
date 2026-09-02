import SwiftUI
import SwiftData

/// Edits one routine: its name, which exercises it contains, in what order, and
/// how many sets each targets.
///
/// Unlike `ExerciseEditorView` (a modal sheet that copies values and writes on
/// Save), this is a pushed screen that edits the model directly through
/// `@Bindable`. That matches the iOS convention: a sheet with Cancel/Save is
/// transactional, a pushed detail screen saves as you go.
struct TemplateEditorView: View {
    /// `@Bindable` gives us bindings *into* a model object, so `$template.name`
    /// writes straight through to SwiftData.
    @Bindable var template: WorkoutTemplate

    @Environment(\.modelContext) private var modelContext
    @State private var isAddingExercises = false

    var body: some View {
        List {
            Section("Name") {
                TextField("Routine name", text: $template.name)
                    .textInputAutocapitalization(.words)
            }

            Section("Exercises") {
                ForEach(template.orderedExercises) { entry in
                    TemplateExerciseRow(entry: entry)
                }
                .onDelete(perform: removeExercises)
                .onMove(perform: moveExercises)

                Button("Add Exercises", systemImage: "plus") {
                    isAddingExercises = true
                }
            }
        }
        .navigationTitle(template.name.isEmpty ? "Routine" : template.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) { EditButton() }
        }
        .sheet(isPresented: $isAddingExercises) {
            ExercisePickerView(excluding: existingExerciseIDs, onAdd: add)
        }
    }

    private var existingExerciseIDs: Set<UUID> {
        Set(template.orderedExercises.compactMap { $0.exercise?.id })
    }

    private func add(_ exercises: [Exercise]) {
        var nextOrder = template.orderedExercises.count
        for exercise in exercises {
            let entry = TemplateExercise(exercise: exercise, sortOrder: nextOrder)
            modelContext.insert(entry)
            entry.template = template
            nextOrder += 1
        }
    }

    private func removeExercises(at offsets: IndexSet) {
        let entries = template.orderedExercises
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var reordered = template.orderedExercises
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, entry) in reordered.enumerated() {
            entry.sortOrder = index
        }
    }
}

/// One exercise line inside the routine, with its target set count.
private struct TemplateExerciseRow: View {
    @Bindable var entry: TemplateExercise

    var body: some View {
        // Stacked rather than crammed into one line: two steppers side by side
        // on a phone leaves no room to read which is which.
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.exercise?.name ?? "Deleted exercise")
                if let group = entry.exercise?.muscleGroup {
                    Text(group.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Stepper(value: $entry.warmUpSets, in: 0...5) {
                Text(warmUpLabel)
                    .font(.subheadline)
                    .foregroundStyle(entry.warmUpSets == 0 ? .secondary : .primary)
                    .monospacedDigit()
            }

            Stepper(value: $entry.targetSets, in: 1...15) {
                Text("\(entry.targetSets) working \(entry.targetSets == 1 ? "set" : "sets")")
                    .font(.subheadline)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }

    private var warmUpLabel: String {
        switch entry.warmUpSets {
        case 0: "No warm-up"
        case 1: "1 warm-up set"
        default: "\(entry.warmUpSets) warm-up sets"
        }
    }
}

#Preview {
    // Pull the sample "Push A" routine out of the preview store.
    let container = SampleData.previewContainer
    let template = try! container.mainContext.fetch(FetchDescriptor<WorkoutTemplate>()).first!

    return NavigationStack {
        TemplateEditorView(template: template)
    }
    .modelContainer(container)
}

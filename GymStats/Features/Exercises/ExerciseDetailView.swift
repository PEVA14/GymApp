import SwiftUI
import SwiftData

/// One exercise: how it has progressed, and every session it appears in.
struct ExerciseDetailView: View {
    let exercise: Exercise

    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @State private var metric: ProgressMetric = .topWeight
    @State private var isEditing = false

    var body: some View {
        List {
            if history.count >= 2 {
                Section {
                    Picker("Metric", selection: $metric) {
                        ForEach(ProgressMetric.allCases) { metric in
                            Text(metric.displayName).tag(metric)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

                    ExerciseProgressChart(history: history, metric: metric, units: units)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            if !exercise.notes.isEmpty {
                Section("Notes") {
                    Text(exercise.notes)
                }
            }

            Section("History") {
                // Newest first for reading, even though the chart runs oldest
                // first for plotting.
                ForEach(history.reversed()) { performed in
                    VStack(alignment: .leading, spacing: 3) {
                        if let date = performed.session?.startedAt {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline)
                        }
                        Text(summary(for: performed))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { emptyStateIfNeeded }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ExerciseEditorView(exercise: exercise)
        }
    }

    private var units: UnitSettings { UnitSettings(weight: weightUnit) }

    private var history: [SessionExercise] {
        exercise.performanceHistory
    }

    private func summary(for performed: SessionExercise) -> String {
        performed.completedSets
            .map { "\(units.weightString(fromKilograms: $0.weightKg)) × \($0.reps)" }
            .joined(separator: "   ")
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if history.isEmpty && exercise.notes.isEmpty {
            ContentUnavailableView(
                "No History",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Perform this exercise in a workout and its progress appears here.")
            )
        }
    }
}

#Preview {
    let container = SampleData.previewContainer
    let exercise = try! container.mainContext.fetch(FetchDescriptor<Exercise>()).first!

    return NavigationStack {
        ExerciseDetailView(exercise: exercise)
    }
    .modelContainer(container)
}

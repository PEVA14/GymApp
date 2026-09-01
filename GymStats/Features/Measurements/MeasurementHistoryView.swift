import SwiftUI
import SwiftData

/// Every recorded value for one measurement type, newest first, with the change
/// from the previous entry.
struct MeasurementHistoryView: View {
    let type: MeasurementType

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var allMeasurements: [BodyMeasurement]

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKey.lengthUnit) private var lengthUnit: LengthUnit = .centimetres

    private var units: UnitSettings { UnitSettings(weight: weightUnit, length: lengthUnit) }

    var body: some View {
        List {
            // A single point is not a trend, so the chart appears once there is
            // something to compare against.
            if entries.count >= 2 {
                Section {
                    MeasurementChart(entries: entries, type: type, units: units)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, measurement in
                LabeledContent {
                    if let delta = change(at: index) {
                        Text(delta)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                } label: {
                    Text("\(units.string(measurement.value, for: type)) \(units.symbol(for: type))")
                        .monospacedDigit()
                    Text(measurement.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !measurement.note.isEmpty {
                        Text(measurement.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .navigationTitle(type.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .overlay { emptyStateIfNeeded }
    }

    /// Filtering in memory rather than in the `@Query`: a dynamic predicate needs
    /// a custom initialiser, and a personal measurement history is small.
    private var entries: [BodyMeasurement] {
        allMeasurements.filter { $0.type == type }
    }

    /// Difference from the next-older entry. The list is newest-first, so the
    /// previous reading is at `index + 1`.
    private func change(at index: Int) -> String? {
        let entries = entries
        guard index + 1 < entries.count else { return nil }
        // Convert both endpoints before subtracting, so the delta is expressed
        // in the unit shown rather than a converted kilogram difference.
        let newer = units.value(entries[index].value, for: type)
        let older = units.value(entries[index + 1].value, for: type)
        let delta = newer - older
        guard abs(delta) > 0.0001 else { return "—" }
        let sign = delta > 0 ? "+" : "−"
        return "\(sign)\(Formatters.weight(abs(delta))) \(units.symbol(for: type))"
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No Entries",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Values you record for \(type.displayName.lowercased()) appear here.")
            )
        }
    }

    private func delete(at offsets: IndexSet) {
        let entries = entries
        for index in offsets {
            modelContext.delete(entries[index])
        }
    }
}

#Preview {
    NavigationStack {
        MeasurementHistoryView(type: .bodyWeight)
    }
    .modelContainer(SampleData.previewContainer)
}

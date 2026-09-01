import SwiftUI
import SwiftData

/// The Body tab: the latest value for each measurement you track.
///
/// Because measurements are stored narrow — one row per `(date, type, value)` —
/// "the latest of each type" is a grouping over one query rather than a wide
/// row with a column per body part.
struct MeasurementListView: View {
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKey.lengthUnit) private var lengthUnit: LengthUnit = .centimetres

    @State private var isLogging = false

    private var units: UnitSettings { UnitSettings(weight: weightUnit, length: lengthUnit) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(latestByType, id: \.type) { entry in
                    NavigationLink(value: entry.type) {
                        LabeledContent {
                            Text("\(units.string(entry.measurement.value, for: entry.type)) \(units.symbol(for: entry.type))")
                                .monospacedDigit()
                        } label: {
                            Text(entry.type.displayName)
                            Text(entry.measurement.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Body")
            .overlay { emptyStateIfNeeded }
            .navigationDestination(for: MeasurementType.self) { type in
                MeasurementHistoryView(type: type)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Log Measurement", systemImage: "plus") { isLogging = true }
                }
            }
            .sheet(isPresented: $isLogging) {
                LogMeasurementView()
            }
        }
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if latestByType.isEmpty {
            ContentUnavailableView(
                "No Measurements",
                systemImage: "figure.arms.open",
                description: Text("Record your body weight and measurements to track them over time.")
            )
        }
    }

    /// Most recent entry per type. The query is already newest-first, so the
    /// first one seen for a type wins. Ordered by `MeasurementType.allCases` so
    /// the list keeps a stable, sensible order rather than shuffling by date.
    private var latestByType: [(type: MeasurementType, measurement: BodyMeasurement)] {
        var newest: [MeasurementType: BodyMeasurement] = [:]
        for measurement in measurements {
            guard let type = measurement.type, newest[type] == nil else { continue }
            newest[type] = measurement
        }
        return MeasurementType.allCases.compactMap { type in
            newest[type].map { (type: type, measurement: $0) }
        }
    }
}

#Preview {
    MeasurementListView()
        .modelContainer(SampleData.previewContainer)
}

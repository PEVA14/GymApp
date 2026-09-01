import SwiftUI
import Charts

/// A trend line for one measurement type.
///
/// Works for any `MeasurementType` without modification — the narrow storage
/// model means a chart is just "these rows, plotted", whatever the body part.
struct MeasurementChart: View {
    let entries: [BodyMeasurement]
    let type: MeasurementType
    /// Values are converted before the domain is computed, so the axis range
    /// always matches the numbers drawn on it.
    let units: UnitSettings

    var body: some View {
        Chart(points) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value(type.displayName, displayValue(entry))
            )
            .interpolationMethod(.linear)

            PointMark(
                x: .value("Date", entry.date),
                y: .value(type.displayName, displayValue(entry))
            )
            .symbolSize(28)
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(Formatters.weight(number))
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }

    /// Charts want ascending time; the surrounding list is newest-first.
    private var points: [BodyMeasurement] {
        entries.sorted { $0.date < $1.date }
    }

    private func displayValue(_ entry: BodyMeasurement) -> Double {
        units.value(entry.value, for: type)
    }

    /// Deliberately **not** zero-based. Body weight moving 78.4 → 77.9 is a
    /// meaningful change, and a 0–80 axis would flatten it into a straight line.
    /// The padding keeps points off the chart edges.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(displayValue)
        guard let lowest = values.min(), let highest = values.max() else { return 0...1 }
        let padding = max((highest - lowest) * 0.2, 0.5)
        return (lowest - padding)...(highest + padding)
    }
}

#Preview {
    let now = Date()
    let entries = (0..<6).map { week in
        BodyMeasurement(
            type: .bodyWeight,
            value: 78.5 - Double(week) * 0.3,
            date: now.addingTimeInterval(Double(-week) * 7 * 86_400)
        )
    }
    return MeasurementChart(entries: entries, type: .bodyWeight, units: UnitSettings())
        .padding()
}

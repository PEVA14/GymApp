import SwiftUI
import Charts

/// Progression over time for one exercise and one metric.
struct ExerciseProgressChart: View {
    /// Finished performances, oldest first.
    let history: [SessionExercise]
    let metric: ProgressMetric
    /// Points are converted to the display unit *before* the axis domain is
    /// derived from them, so the scale and its labels can never disagree.
    let units: UnitSettings

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Date", point.date),
                y: .value(metric.displayName, point.value)
            )
            .interpolationMethod(.linear)

            PointMark(
                x: .value("Date", point.date),
                y: .value(metric.displayName, point.value)
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
            AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
        }
        .frame(height: 180)
        .padding(.vertical, 8)
    }

    private var points: [ProgressPoint] {
        history.compactMap { performed in
            guard let date = performed.session?.startedAt else { return nil }
            let kilograms = metric.value(for: performed)
            return ProgressPoint(
                id: performed.id,
                date: date,
                value: units.weightValue(fromKilograms: kilograms)
            )
        }
    }

    /// Volume starts at zero because it is a quantity of work — half the volume
    /// really is half the work. Weight metrics do not, because the interesting
    /// range is the top few kilos and a zero baseline flattens it.
    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        guard let lowest = values.min(), let highest = values.max() else { return 0...1 }

        if metric == .volume {
            return 0...(highest * 1.1 + 1)
        }
        let padding = max((highest - lowest) * 0.2, 1)
        return max(lowest - padding, 0)...(highest + padding)
    }
}

private struct ProgressPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double
}

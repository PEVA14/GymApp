import Foundation

/// Shared display formatting. Lives here so the active workout, history, and
/// later the widgets and watch app all render values identically.
enum Formatters {
    /// Running clock for a live workout: `0:02:01`.
    static func clock(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        return String(format: "%d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }

    /// Rest countdown: `1:30`, or `0:07`.
    static func countdown(_ interval: TimeInterval) -> String {
        let total = max(Int(interval.rounded(.up)), 0)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Human-readable length of a finished workout: `1h 5m`, or `48m`.
    static func compactDuration(_ interval: TimeInterval) -> String {
        let minutes = max(Int(interval) / 60, 0)
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    /// Drops the decimal on whole numbers: `30`, but `27.5` keeps it.
    static func weight(_ kilograms: Double) -> String {
        kilograms.rounded() == kilograms
            ? String(Int(kilograms))
            : String(format: "%.1f", kilograms)
    }
}

import Foundation

/// User-facing keys for the unit preferences, so the `@AppStorage` string is
/// written once rather than repeated in every view that reads it.
enum SettingsKey {
    static let weightUnit = "weightUnit"
    static let lengthUnit = "lengthUnit"
    /// Seconds of rest started when a set is completed. `0` disables the timer.
    static let defaultRestSeconds = "defaultRestSeconds"
    /// Whether to post a lock-screen alert when rest ends.
    static let restAlertsEnabled = "restAlertsEnabled"
}

/// Rest lengths offered in Settings. Deliberately a short list of the durations
/// people actually use, rather than a free-text field to fumble with mid-set.
enum RestDuration {
    static let options = [0, 30, 45, 60, 90, 120, 150, 180, 240, 300]
    static let `default` = 90

    static func label(for seconds: Int) -> String {
        guard seconds > 0 else { return "Off" }
        return seconds < 60
            ? "\(seconds)s"
            : (seconds % 60 == 0 ? "\(seconds / 60) min" : "\(seconds / 60) min \(seconds % 60)s")
    }
}

/// Translates canonical stored values (kilograms, centimetres) into whatever the
/// user has chosen to see, and back again for input.
///
/// This is the single boundary between storage and display. The store stays
/// canonical no matter what is selected here — nothing in `Models/` knows a
/// preference exists — so switching units can never alter recorded history.
struct UnitSettings {
    var weight: WeightUnit = .kilograms
    var length: LengthUnit = .centimetres

    // MARK: Training weights

    var weightSymbol: String { weight.symbol }

    func weightValue(fromKilograms kilograms: Double) -> Double {
        weight.fromKilograms(kilograms)
    }

    /// Parses a value the user typed, in their chosen unit, back to kilograms.
    func kilograms(fromDisplayed value: Double) -> Double {
        weight.toKilograms(value)
    }

    /// Formatted number without the unit, e.g. `27.5`.
    func weightString(fromKilograms kilograms: Double) -> String {
        Formatters.weight(weightValue(fromKilograms: kilograms))
    }

    /// Formatted number with the unit, e.g. `27.5 kg`.
    func weightWithSymbol(fromKilograms kilograms: Double) -> String {
        "\(weightString(fromKilograms: kilograms)) \(weightSymbol)"
    }

    /// Training volume is a mass quantity (weight × reps), so it converts with
    /// the weight unit like any other load.
    func volumeWithSymbol(fromKilograms kilograms: Double) -> String {
        weightWithSymbol(fromKilograms: kilograms)
    }

    // MARK: Body measurements

    /// Body weight follows the weight unit; lengths follow the length unit.
    func symbol(for type: MeasurementType) -> String {
        switch type.dimension {
        case .mass: weight.symbol
        case .length: length.symbol
        }
    }

    func value(_ canonical: Double, for type: MeasurementType) -> Double {
        switch type.dimension {
        case .mass: weight.fromKilograms(canonical)
        case .length: length.fromCentimetres(canonical)
        }
    }

    func canonicalValue(_ displayed: Double, for type: MeasurementType) -> Double {
        switch type.dimension {
        case .mass: weight.toKilograms(displayed)
        case .length: length.toCentimetres(displayed)
        }
    }

    func string(_ canonical: Double, for type: MeasurementType) -> String {
        Formatters.weight(value(canonical, for: type))
    }
}

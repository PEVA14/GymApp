import Foundation

/// Unit handling lives here, and *only* here.
///
/// The rule for the whole app: the store holds canonical units (kilograms for
/// mass, centimetres for length). Conversion happens at the edges — when
/// formatting for display, and when parsing user input. Nothing in `Models/`
/// ever knows what unit the user prefers.
enum WeightUnit: String, CaseIterable, Identifiable, Codable {
    case kilograms, pounds

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }

    var displayName: String {
        switch self {
        case .kilograms: "Kilograms (kg)"
        case .pounds: "Pounds (lb)"
        }
    }

    /// Canonical (kg) -> display value in this unit.
    func fromKilograms(_ kg: Double) -> Double {
        switch self {
        case .kilograms: kg
        case .pounds: kg * 2.2046226218
        }
    }

    /// Display value in this unit -> canonical (kg).
    func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kilograms: value
        case .pounds: value / 2.2046226218
        }
    }
}

enum LengthUnit: String, CaseIterable, Identifiable, Codable {
    case centimetres, inches

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .centimetres: "cm"
        case .inches: "in"
        }
    }

    var displayName: String {
        switch self {
        case .centimetres: "Centimetres (cm)"
        case .inches: "Inches (in)"
        }
    }

    func fromCentimetres(_ cm: Double) -> Double {
        switch self {
        case .centimetres: cm
        case .inches: cm / 2.54
        }
    }

    func toCentimetres(_ value: Double) -> Double {
        switch self {
        case .centimetres: value
        case .inches: value * 2.54
        }
    }
}

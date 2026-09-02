import Foundation

/// Broad categorisation for an exercise. Used for grouping and filtering the
/// exercise library. Deliberately coarse — this is for finding exercises
/// quickly, not for anatomically accurate classification.
enum MuscleGroup: String, CaseIterable, Identifiable, Codable {
    case chest, back, shoulders, biceps, triceps, legs, glutes, core, cardio, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .legs: "Legs"
        case .glutes: "Glutes"
        case .core: "Core"
        case .cardio: "Cardio"
        case .other: "Other"
        }
    }
}

/// Whether a set is real work or a ramp-up to it.
///
/// Warm-up sets are recorded — they are part of what you did — but they are
/// excluded from every derived statistic. A 20 kg ramp-up set counted as volume
/// would inflate your training load, and counted as a performance it could
/// register a personal record you never made.
enum SetKind: String, CaseIterable, Identifiable, Codable {
    case working
    case warmUp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .working: "Working Set"
        case .warmUp: "Warm-up"
        }
    }
}

/// What kind of physical quantity a measurement is, which determines its
/// canonical storage unit and how it is formatted.
enum MeasurementDimension {
    case mass    // stored in kilograms
    case length  // stored in centimetres
}

/// The kinds of body measurement the app can record.
///
/// Adding a new measurement type means adding a case here — no SwiftData schema
/// change and no migration, because `BodyMeasurement` stores the raw string.
enum MeasurementType: String, CaseIterable, Identifiable, Codable {
    case bodyWeight
    case waist
    case chest
    case biceps
    case hips
    case thigh
    case neck
    case forearm
    case calf

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bodyWeight: "Body Weight"
        case .waist: "Waist"
        case .chest: "Chest"
        case .biceps: "Biceps"
        case .hips: "Hips"
        case .thigh: "Thigh"
        case .neck: "Neck"
        case .forearm: "Forearm"
        case .calf: "Calf"
        }
    }

    var dimension: MeasurementDimension {
        switch self {
        case .bodyWeight: .mass
        default: .length
        }
    }

    /// The unit values of this type are stored in. Display conversion happens in
    /// `Core/Units.swift`, never here.
    var canonicalUnitSymbol: String {
        switch dimension {
        case .mass: "kg"
        case .length: "cm"
        }
    }
}

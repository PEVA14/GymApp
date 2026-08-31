import Foundation
import SwiftData

/// A single recorded body measurement: one type, one value, one date.
///
/// This is deliberately "narrow" — one row per measurement rather than one row
/// per date with a column per body part. Adding a new measurement type means
/// adding a case to `MeasurementType`; there is no schema change and no
/// migration. It is also the shape charts want, and it mirrors how HealthKit
/// models samples.
///
/// `value` is in the canonical unit for its dimension: kilograms for mass,
/// centimetres for length.
@Model
final class BodyMeasurement {
    var id: UUID = UUID()
    var date: Date = Date()
    var typeRaw: String = MeasurementType.bodyWeight.rawValue
    var value: Double = 0
    var note: String = ""

    init(type: MeasurementType, value: Double, date: Date = Date(), note: String = "") {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.value = value
        self.date = date
        self.note = note
    }

    /// Optional because a value written by a future version of the app may not
    /// be a case we know about. Callers should skip unknown measurements rather
    /// than crash.
    var type: MeasurementType? {
        get { MeasurementType(rawValue: typeRaw) }
        set { if let newValue { typeRaw = newValue.rawValue } }
    }
}

import SwiftUI
import SwiftData

/// Records one measurement. A sheet with Cancel/Save, so backing out writes
/// nothing — the same transactional pattern as `ExerciseEditorView`.
struct LogMeasurementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKey.lengthUnit) private var lengthUnit: LengthUnit = .centimetres

    @State private var type: MeasurementType = .bodyWeight
    @State private var valueText = ""
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Measurement", selection: $type) {
                        ForEach(MeasurementType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }

                    LabeledContent(units.symbol(for: type)) {
                        TextField("Value", text: $valueText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Note") {
                    TextField("Optional", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                }
            }
            .navigationTitle("Log Measurement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(parsedValue == nil)
                }
            }
        }
    }

    private var units: UnitSettings { UnitSettings(weight: weightUnit, length: lengthUnit) }

    /// Accepts a comma as the decimal separator, matching the keyboard a Spanish
    /// locale shows. A measurement of zero or less is not a typo worth saving.
    /// The result is in the user's chosen unit — `save()` converts it.
    private var parsedValue: Double? {
        guard let value = Double(valueText.replacingOccurrences(of: ",", with: ".")),
              value > 0
        else { return nil }
        return value
    }

    private func save() {
        guard let value = parsedValue else { return }
        // `value` is in the user's chosen unit; storage is always canonical.
        modelContext.insert(
            BodyMeasurement(
                type: type,
                value: units.canonicalValue(value, for: type),
                date: date,
                note: note
            )
        )
        dismiss()
    }
}

#Preview {
    LogMeasurementView()
        .modelContainer(SampleData.previewContainer)
}

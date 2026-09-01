import SwiftUI
import UIKit

/// Display unit preferences.
///
/// These affect presentation only. Weights are always stored in kilograms and
/// lengths in centimetres, so switching here re-renders your history in the new
/// unit without rewriting a single stored value.
struct SettingsView: View {
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKey.lengthUnit) private var lengthUnit: LengthUnit = .centimetres
    @AppStorage(SettingsKey.defaultRestSeconds) private var restSeconds: Int = RestDuration.default
    @AppStorage(SettingsKey.restAlertsEnabled) private var restAlertsEnabled = false

    @State private var isShowingPermissionAlert = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Weight", selection: $weightUnit) {
                        ForEach(WeightUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    Picker("Lengths", selection: $lengthUnit) {
                        ForEach(LengthUnit.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                } header: {
                    Text("Units")
                } footer: {
                    Text("Changes how values are shown. Your recorded workouts and measurements are unchanged.")
                }

                Section {
                    Picker("Rest Timer", selection: $restSeconds) {
                        ForEach(RestDuration.options, id: \.self) { seconds in
                            Text(RestDuration.label(for: seconds)).tag(seconds)
                        }
                    }

                    Toggle("Alert When Rest Ends", isOn: $restAlertsEnabled)
                        .disabled(restSeconds == 0)
                } header: {
                    Text("Workout")
                } footer: {
                    Text("The timer starts automatically when you complete a set. The alert notifies you with the app closed or your phone locked.")
                }
            }
            .onChange(of: restAlertsEnabled) { _, isEnabled in
                guard isEnabled else {
                    RestNotifications.cancel()
                    return
                }
                // Permission is requested at the moment the user asks for the
                // feature, not on launch, so the prompt has obvious context.
                Task {
                    if await !RestNotifications.requestAuthorization() {
                        restAlertsEnabled = false
                        isShowingPermissionAlert = true
                    }
                }
            }
            .alert("Notifications Are Off", isPresented: $isShowingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Not Now", role: .cancel) { }
            } message: {
                Text("Allow notifications for GymStats in the Settings app to be alerted when your rest ends.")
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}

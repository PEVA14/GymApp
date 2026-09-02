import SwiftUI
import SwiftData

/// A read-only record of one finished workout.
///
/// Deliberately not editable. History is the app's source of truth for every
/// future statistic, and an accidental swipe in a list you are only browsing
/// should not be able to rewrite what you lifted in March.
struct SessionDetailView: View {
    let session: WorkoutSession

    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms

    private var units: UnitSettings { UnitSettings(weight: weightUnit) }

    /// Matches the active workout: warm-ups read "W", working sets are numbered
    /// among themselves.
    private func label(for set: SetEntry, among sets: [SetEntry]) -> String {
        if set.isWarmUp { return "W" }
        let workingNumber = sets
            .prefix { $0.id != set.id }
            .count(where: { !$0.isWarmUp })
        return "\(workingNumber + 1)"
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date", value: session.startedAt.formatted(date: .long, time: .shortened))
                LabeledContent("Duration", value: Formatters.compactDuration(session.duration))
                LabeledContent("Sets", value: "\(TrainingMath.completedSetCount(of: session))")
                LabeledContent("Volume", value: units.volumeWithSymbol(fromKilograms: TrainingMath.volume(of: session)))
            }

            ForEach(session.orderedExercises) { performed in
                let sets = performed.completedSets
                if !sets.isEmpty {
                    let records = performed.personalRecordSetIDs()
                    Section(performed.displayName) {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { index, set in
                            HStack {
                                Text(label(for: set, among: sets))
                                    .font(.subheadline)
                                    .foregroundStyle(set.isWarmUp ? .orange : .secondary)
                                    .frame(width: 18, alignment: .leading)
                                Text("\(units.weightWithSymbol(fromKilograms: set.weightKg)) × \(set.reps)")
                                Spacer()
                                if records.contains(set.id) {
                                    PersonalRecordBadge()
                                }
                            }
                            .monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle(session.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = SampleData.previewContainer
    let session = try! container.mainContext.fetch(FetchDescriptor<WorkoutSession>()).first!

    return NavigationStack {
        SessionDetailView(session: session)
    }
    .modelContainer(container)
}

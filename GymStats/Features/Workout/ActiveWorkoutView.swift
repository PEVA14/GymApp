import SwiftUI
import SwiftData

/// The screen you actually use in the gym.
///
/// Every edit here writes straight to SwiftData — there is no in-memory draft of
/// the workout. That is deliberate: the session already exists in the store from
/// the moment you tapped Start, so closing the app mid-workout loses nothing,
/// and a Live Activity or watch app can later read the same rows.
struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage(SettingsKey.defaultRestSeconds)
    private var defaultRestSeconds: Int = RestDuration.default
    @AppStorage(SettingsKey.restAlertsEnabled)
    private var restAlertsEnabled: Bool = false

    @State private var isConfirmingDiscard = false
    /// Bumped when a rest period ends, purely to drive the haptic.
    @State private var restCompletionCount = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // TimelineView re-renders on a schedule, which gives us a
                    // live clock without owning a Timer or a controller object.
                    TimelineView(.periodic(from: session.startedAt, by: 1)) { _ in
                        LabeledContent("Duration", value: Formatters.clock(session.duration))
                            .monospacedDigit()
                    }
                }

                if session.restEndsAt != nil {
                    Section {
                        RestBar(session: session)
                    }
                }

                ForEach(session.orderedExercises) { performed in
                    ExerciseSection(performed: performed, onSetCompleted: startRest)
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) {
                        isConfirmingDiscard = true
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish", action: finish)
                }
            }
            .confirmationDialog(
                "Discard this workout?",
                isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard Workout", role: .destructive, action: discard)
            } message: {
                Text("Everything you logged in this session will be deleted.")
            }
        }
        .interactiveDismissDisabled()
        // Re-runs whenever the rest end date changes, and is cancelled
        // automatically if the timer is adjusted or skipped. That is why no
        // Timer object needs owning, starting, or invalidating.
        .task(id: session.restEndsAt) {
            guard let endsAt = session.restEndsAt else {
                RestNotifications.cancel()
                return
            }

            // Scheduling here rather than at each call site means every change
            // to the rest — start, ±15s, skip — re-runs this and replaces the
            // pending alert. There is no path that leaves a stale one queued.
            if restAlertsEnabled {
                RestNotifications.schedule(at: endsAt)
            }

            let remaining = endsAt.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            session.stopRest()
            restCompletionCount += 1
        }
        .sensoryFeedback(.success, trigger: restCompletionCount)
    }

    /// Called when a set is ticked. `0` seconds means the user turned the timer
    /// off in Settings, so nothing starts.
    private func startRest() {
        session.startRest(seconds: defaultRestSeconds)
    }

    private func finish() {
        RestNotifications.cancel()
        session.stopRest()
        session.finish(in: modelContext)
        dismiss()
    }

    private func discard() {
        RestNotifications.cancel()
        // Cascade delete rules clear the exercises and sets with it.
        modelContext.delete(session)
        dismiss()
    }
}

/// One exercise inside the workout: its set rows plus an Add Set button.
private struct ExerciseSection: View {
    let performed: SessionExercise
    let onSetCompleted: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms

    private var units: UnitSettings { UnitSettings(weight: weightUnit) }

    var body: some View {
        Section(performed.displayName) {
            if let previous = performed.previousPerformance {
                PreviousPerformanceRow(previous: previous, units: units)
            }

            ForEach(Array(performed.orderedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(
                    set: set,
                    number: index + 1,
                    isPersonalRecord: recordSetIDs.contains(set.id),
                    units: units,
                    onCompleted: onSetCompleted
                )
            }
            .onDelete(perform: deleteSets)

            Button("Add Set", systemImage: "plus", action: addSet)
                .font(.subheadline)
        }
    }

    /// Recomputed as you type, so the badge appears the moment a set beats
    /// your old record rather than after the workout ends.
    private var recordSetIDs: Set<UUID> {
        performed.personalRecordSetIDs()
    }

    private func addSet() {
        let sets = performed.orderedSets
        let new = SetEntry(sortOrder: (sets.last?.sortOrder ?? -1) + 1)

        // Carry forward from the last set that actually has numbers in it, not
        // simply the last row — sets are pre-filled from the routine, so the
        // trailing rows are usually still blank.
        if let lastFilled = sets.last(where: { $0.weightKg > 0 || $0.reps > 0 }) {
            new.weightKg = lastFilled.weightKg
            new.reps = lastFilled.reps
        }

        modelContext.insert(new)
        new.sessionExercise = performed
    }

    private func deleteSets(at offsets: IndexSet) {
        let sets = performed.orderedSets
        for index in offsets {
            modelContext.delete(sets[index])
        }
    }
}

/// What you did for this exercise last time, so you know what to beat.
private struct PreviousPerformanceRow: View {
    let previous: SessionExercise
    let units: UnitSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Last time\(dateSuffix)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(setsSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .listRowBackground(Color.clear)
    }

    private var dateSuffix: String {
        guard let date = previous.session?.startedAt else { return "" }
        return " · \(date.formatted(.dateTime.day().month(.abbreviated)))"
    }

    private var setsSummary: String {
        previous.completedSets
            .map { "\(units.weightString(fromKilograms: $0.weightKg)) × \($0.reps)" }
            .joined(separator: "   ")
    }
}

/// A single set: weight × reps, and a tick to mark it done.
private struct SetRow: View {
    @Bindable var set: SetEntry
    let number: Int
    let isPersonalRecord: Bool
    let units: UnitSettings
    let onCompleted: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 18, alignment: .leading)

            TextField(units.weightSymbol, text: weightText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)

            Text("×")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("reps", text: repsText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 55)

            Spacer()

            if isPersonalRecord {
                PersonalRecordBadge()
            }

            Button {
                toggleCompleted()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Mark set \(number) incomplete" : "Mark set \(number) complete")
        }
        .monospacedDigit()
    }

    /// Text bindings rather than `format: .number`, for two reasons: an unset
    /// value shows the placeholder instead of a literal "0" you have to clear,
    /// and a comma typed on a Spanish keyboard is accepted as a decimal point.
    private var weightText: Binding<String> {
        Binding(
            get: { set.weightKg == 0 ? "" : units.weightString(fromKilograms: set.weightKg) },
            set: {
                let typed = Double($0.replacingOccurrences(of: ",", with: ".")) ?? 0
                // The user types in their chosen unit; the store stays canonical.
                set.weightKg = units.kilograms(fromDisplayed: typed)
            }
        )
    }

    private var repsText: Binding<String> {
        Binding(
            get: { set.reps == 0 ? "" : String(set.reps) },
            set: { set.reps = Int($0) ?? 0 }
        )
    }

    private func toggleCompleted() {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? Date() : nil
        // Rest starts on completion, not on un-ticking a mistake.
        if set.isCompleted { onCompleted() }
    }
}

#Preview {
    let container = SampleData.previewContainer
    let context = container.mainContext
    let template = try! context.fetch(FetchDescriptor<WorkoutTemplate>()).first!
    let session = WorkoutSession.start(from: template, in: context)

    return ActiveWorkoutView(session: session)
        .modelContainer(container)
}

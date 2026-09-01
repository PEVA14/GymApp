import SwiftUI
import SwiftData

/// Finished workouts, newest first, grouped by month.
struct SessionListView: View {
    /// Only completed workouts. An in-progress session (`endedAt == nil`) belongs
    /// on the Train tab as "Resume", not in history.
    @Query(
        filter: #Predicate<WorkoutSession> { $0.endedAt != nil },
        sort: \WorkoutSession.startedAt,
        order: .reverse
    )
    private var sessions: [WorkoutSession]

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.weightUnit) private var weightUnit: WeightUnit = .kilograms

    private var units: UnitSettings { UnitSettings(weight: weightUnit) }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessionsByMonth, id: \.month) { group in
                    Section(group.month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                row(for: session)
                            }
                        }
                        .onDelete { deleteSessions(in: group.sessions, at: $0) }
                    }
                }
            }
            .navigationTitle("History")
            .overlay { emptyStateIfNeeded }
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func row(for session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.name)
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(summary(for: session))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func summary(for session: WorkoutSession) -> String {
        let sets = TrainingMath.completedSetCount(of: session)
        let volume = TrainingMath.volume(of: session)
        let setLabel = sets == 1 ? "1 set" : "\(sets) sets"
        return "\(Formatters.compactDuration(session.duration)) · \(setLabel) · \(units.volumeWithSymbol(fromKilograms: volume))"
    }

    @ViewBuilder
    private var emptyStateIfNeeded: some View {
        if sessions.isEmpty {
            ContentUnavailableView(
                "No Workouts Yet",
                systemImage: "clock.arrow.circlepath",
                description: Text("Finished workouts appear here.")
            )
        }
    }

    private var sessionsByMonth: [(month: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        return Dictionary(grouping: sessions) { session in
            calendar.date(from: calendar.dateComponents([.year, .month], from: session.startedAt))
                ?? session.startedAt
        }
        .map { (month: $0.key, sessions: $0.value) }
        .sorted { $0.month > $1.month }
    }

    /// The offsets are relative to the section's own array, not the flat query.
    private func deleteSessions(in sessions: [WorkoutSession], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(SampleData.previewContainer)
}

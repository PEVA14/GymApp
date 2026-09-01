import SwiftUI

/// The live rest countdown, with quick adjustments and a skip.
///
/// There is no timer object behind this. `TimelineView` re-renders once a
/// second and the remaining time is recomputed from the stored end date, so the
/// display is correct even if the app was backgrounded for the whole rest.
struct RestBar: View {
    @Bindable var session: WorkoutSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = session.restRemaining(at: context.date)

            HStack(spacing: 14) {
                Button {
                    session.adjustRest(by: -15)
                } label: {
                    Label("Subtract 15 seconds", systemImage: "gobackward.15")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.borderless)

                VStack(spacing: 1) {
                    Text(Formatters.countdown(remaining))
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button {
                    session.adjustRest(by: 15)
                } label: {
                    Label("Add 15 seconds", systemImage: "goforward.15")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
                .buttonStyle(.borderless)

                Button("Skip") {
                    session.stopRest()
                }
                .buttonStyle(.borderless)
                .font(.subheadline)
            }
            .padding(.vertical, 2)
        }
    }
}

#Preview {
    let session = WorkoutSession(name: "Push A")
    session.startRest(seconds: 90)
    return List {
        Section { RestBar(session: session) }
    }
}

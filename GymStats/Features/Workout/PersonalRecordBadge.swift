import SwiftUI

/// Marks a set that beat every previous performance of that exercise.
///
/// Shared between the active workout and history so a record looks identical
/// whether you are setting it or reading it back later.
struct PersonalRecordBadge: View {
    var body: some View {
        Text("PR")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.orange)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.orange.opacity(0.15), in: .capsule)
            .accessibilityLabel("Personal record")
    }
}

#Preview {
    PersonalRecordBadge()
}

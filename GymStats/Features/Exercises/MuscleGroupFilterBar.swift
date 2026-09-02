import SwiftUI

/// A horizontally scrolling row of muscle-group chips.
///
/// Shared by the exercise library and the routine's exercise picker — the same
/// control in both places, so it lives in one file rather than being copied.
///
/// Multi-select: "Biceps + Triceps" is a normal way to look for an arm
/// movement, and tapping one group at a time would make that impossible.
/// Selecting nothing means no filter, which is also what "All" resets to.
struct MuscleGroupFilterBar: View {
    let groups: [MuscleGroup]
    @Binding var selection: Set<MuscleGroup>

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: "All", isOn: selection.isEmpty) { selection = [] }

                ForEach(groups) { group in
                    chip(title: group.displayName, isOn: selection.contains(group)) {
                        toggle(group)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }

    private func chip(title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary),
                            in: .capsule)
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggle(_ group: MuscleGroup) {
        if selection.contains(group) {
            selection.remove(group)
        } else {
            selection.insert(group)
        }
    }
}

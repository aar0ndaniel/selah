import SwiftUI

/// Small card on Today while quiet time is on. Brand tint, moon icon, and an End button that only hides the card
/// (it does not change the user's Focus; that is done in iOS).
struct QuietTimeBanner: View {
    var onEnd: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: Theme.Spacing.s))

        layout {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                PIconView(.moon, filled: true, size: 26, relativeTo: .title3)
                    .foregroundStyle(Theme.brandInk)
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text("Quiet time is on")
                        .font(.selahHeadline)
                        .foregroundStyle(Theme.brandInk)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your Focus keeps notifications away.")
                        .font(.selahLabel)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .combine)

            Button(action: onEnd) {
                Text("End")
                    .font(.selahLabel.weight(.semibold))
                    .foregroundStyle(Theme.brandInk)
                    .padding(.horizontal, Theme.Spacing.m)
                    .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                    .background(Color(.systemBackground).opacity(0.7), in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("End quiet time")
            .accessibilityHint("Hides this card. Turn the Focus off in Control Center.")
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Theme.brandFill,
            in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        )
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.m) {
        QuietTimeBanner {}
    }
    .padding(Theme.Spacing.m)
}

import SwiftUI

// Button hierarchy (see docs/DESIGN-SYSTEM.md):
//   primary   : filled accent capsule. One per screen, the main action.
//   secondary : tinted capsule in a tone (fill background, ink label). Supporting actions.
//   tertiary  : accent text, or a hairline outlined capsule. Low-emphasis and "cancel"-style actions.
//
// All styles: at least 44pt tall, pressed state scales to 0.97 (a quiet fade instead when Reduce Motion is on),
// no haptics (callers add `.sensoryFeedback`). Labels wrap instead of truncating at large text sizes.

/// Shared pressed-state behaviour.
private struct PressedEffect: ViewModifier {
    let isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(isPressed && reduceMotion ? 0.7 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: isPressed)
    }
}

// MARK: - Primary

/// Filled accent capsule. The label is `systemBackground`: white on the deep teal in light mode and black on
/// the bright teal in dark mode, which keeps contrast above 5:1 in both.
struct SelahPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(Color(.systemBackground))
            .padding(.horizontal, Theme.Spacing.l)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil, minHeight: 48)
            .background(Color.accentColor, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(PressedEffect(isPressed: configuration.isPressed))
    }
}

// MARK: - Secondary

/// Tinted capsule: `tone.fill` background with `tone.ink` label.
struct SelahSecondaryButtonStyle: ButtonStyle {
    var tone: Tone = .teal
    var fullWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(tone.ink)
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil, minHeight: Theme.minTapTarget)
            .background(tone.fill, in: Capsule())
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(PressedEffect(isPressed: configuration.isPressed))
    }
}

// MARK: - Tertiary

/// Accent text with no container (or a hairline accent outline when `outlined`).
struct SelahTertiaryButtonStyle: ButtonStyle {
    var outlined: Bool = false
    var fullWidth: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, outlined ? Theme.Spacing.m : Theme.Spacing.xs)
            .padding(.vertical, Theme.Spacing.xs)
            .frame(maxWidth: fullWidth ? CGFloat.infinity : nil, minHeight: Theme.minTapTarget)
            .background {
                if outlined {
                    Capsule().strokeBorder(Color.accentColor, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
            .modifier(PressedEffect(isPressed: configuration.isPressed))
    }
}

// MARK: - Static member shortcuts

extension ButtonStyle where Self == SelahPrimaryButtonStyle {
    /// `.buttonStyle(.selahPrimary)`: hugs its label.
    static var selahPrimary: SelahPrimaryButtonStyle { SelahPrimaryButtonStyle() }
    /// `.buttonStyle(.selahPrimaryFull)`: fills the available width.
    static var selahPrimaryFull: SelahPrimaryButtonStyle { SelahPrimaryButtonStyle(fullWidth: true) }
}

extension ButtonStyle where Self == SelahSecondaryButtonStyle {
    /// `.buttonStyle(.selahSecondary(tone: .coral))`.
    static func selahSecondary(tone: Tone = .teal, fullWidth: Bool = false) -> SelahSecondaryButtonStyle {
        SelahSecondaryButtonStyle(tone: tone, fullWidth: fullWidth)
    }
}

extension ButtonStyle where Self == SelahTertiaryButtonStyle {
    /// `.buttonStyle(.selahTertiary)`: plain accent text.
    static var selahTertiary: SelahTertiaryButtonStyle { SelahTertiaryButtonStyle() }
    /// `.buttonStyle(.selahTertiaryOutlined)`: hairline outlined capsule.
    static var selahTertiaryOutlined: SelahTertiaryButtonStyle { SelahTertiaryButtonStyle(outlined: true) }
}

// MARK: - Pill

/// Small status / metadata pill: optional icon and a short label on a tone.
/// Not interactive (no 44pt target); wrap it in a Button with `.selahSecondary` if it must be tappable.
struct Pill: View {
    let text: String
    var icon: PIcon? = nil
    var tone: Tone = .slate

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                PIconView(icon, size: 14, relativeTo: .footnote)
            }
            Text(text)
                .font(.footnote.weight(.semibold))
        }
        .foregroundStyle(tone.ink)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 6)
        .background(tone.fill, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#Preview("Buttons") {
    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
        Button("Write today's entry") {}
            .buttonStyle(.selahPrimaryFull)
        Button("Add a book") {}
            .buttonStyle(.selahPrimary)
        Button("Add a book") {}
            .buttonStyle(.selahPrimary)
            .disabled(true)
        HStack {
            Button { } label: { Label("Share", picon: .export) }
                .buttonStyle(.selahSecondary(tone: .sky))
            Button { } label: { Label("Edit", picon: .pencilSimple) }
                .buttonStyle(.selahSecondary(tone: .coral))
            Button("Cancel") {}
                .buttonStyle(.selahTertiary)
        }
        Button("Skip for now") {}
            .buttonStyle(.selahTertiaryOutlined)
        HStack {
            Pill(text: "Reading", icon: .bookOpen, tone: .teal)
            Pill(text: "Done", icon: .check, tone: .sage)
            Pill(text: "5 day streak", icon: .flame, tone: .coral)
        }
    }
    .padding(Theme.Spacing.m)
}

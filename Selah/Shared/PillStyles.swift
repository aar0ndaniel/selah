import SwiftUI

// Pill variants (owner reference 6), next to the original `Pill(text:icon:tone:)` in Buttons.swift.
//
//   .soft(tone)      tinted fill, tone ink icon and text
//   .outlined(tone)  tinted fill plus a hairline border in the tone's ink
//   .solid(tone)     filled with the tone's INK, label in the page colour (see contrast note)
//   .accent          filled with the brand red, label in the page colour
//   .neutral         page-colour fill, hairline border, slate ink
//   .neutralDark     solid label colour (black in light mode), label in the page colour
//   .disabled        quiet grey, for things that are off
//
// Contrast (all text is semibold footnote/subheadline, so it needs 4.5:1):
// - soft / outlined: `tone.ink` on `tone.fill`, 7.3:1 or better in light and 8.2:1 in dark (Theme.swift).
// - solid: the fill is `tone.ink`, the label is `systemBackground` (white in light, black in dark). Every ink is at
//   least 7.3:1 against its own pale fill, and that fill is itself close to white, so ink against pure white is at
//   least that high. In dark mode inks are light and the label is black, again above the 8.2:1 dark figure.
//   White on the tone's mid-tone fill would NOT pass, which is why the ink is used as the solid colour.
// - accent: white on #D33E43 is 4.6:1, black on dark #E2585D is 5.8:1 (same pair as the primary button).
// - neutral: `Tone.slate.ink` on `systemBackground`; slate ink is at least 7.3:1 on the pale slate fill, so on white
//   it is higher. neutralDark is `label` on `systemBackground`, the system maximum.
// - disabled: not interactive and not required to meet contrast, but `secondaryLabel` on a tertiary fill is kept
//   readable (about 4.5:1).

enum SelahPillStyle: Hashable, Sendable {
    case soft(Tone)
    case outlined(Tone)
    case solid(Tone)
    case accent
    case neutral
    case neutralDark
    case disabled
}

enum SelahPillSize: Sendable {
    /// 28pt tall, footnote text. For rows of metadata.
    case small
    /// 32pt tall, subheadline text.
    case regular
}

/// A small status or metadata pill. Not interactive; wrap it in a Button with its own 44pt target if it must be tapped.
struct SelahPill: View {
    let text: String
    var icon: PIcon? = nil
    var style: SelahPillStyle = .soft(.slate)
    var size: SelahPillSize = .small

    @ScaledMetric(relativeTo: .footnote) private var smallHeight: CGFloat = 28
    @ScaledMetric(relativeTo: .subheadline) private var regularHeight: CGFloat = 32

    init(_ text: String, icon: PIcon? = nil, style: SelahPillStyle = .soft(.slate), size: SelahPillSize = .small) {
        self.text = text
        self.icon = icon
        self.style = style
        self.size = size
    }

    private var minHeight: CGFloat { size == .small ? smallHeight : regularHeight }

    private var foreground: Color {
        switch style {
        case .soft(let tone), .outlined(let tone): return tone.ink
        case .solid, .accent, .neutralDark: return Color(.systemBackground)
        case .neutral: return Tone.slate.ink
        case .disabled: return Color(.secondaryLabel)
        }
    }

    private var fill: Color {
        switch style {
        case .soft(let tone), .outlined(let tone): return tone.fill
        case .solid(let tone): return tone.ink
        case .accent: return Theme.accent
        case .neutral: return Color(.systemBackground)
        case .neutralDark: return Color(.label)
        case .disabled: return Color(.tertiarySystemFill)
        }
    }

    /// Hairline colour, or nil for none.
    private var border: Color? {
        switch style {
        case .outlined(let tone): return tone.ink.opacity(0.35)
        case .neutral: return Color(.separator)
        default: return nil
        }
    }

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                PIconView(icon, size: size == .small ? 14 : 16, relativeTo: size == .small ? .footnote : .subheadline)
            }
            Text(text)
                .font((size == .small ? Font.footnote : Font.subheadline).weight(.semibold))
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, size == .small ? Theme.Spacing.s : Theme.Spacing.m - 2)
        .padding(.vertical, 4)
        .frame(minHeight: minHeight)
        .background(fill, in: Capsule())
        .overlay {
            if let border {
                Capsule().strokeBorder(border, lineWidth: 1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lays pills out left to right and wraps them onto new lines, so a row of pills never truncates at large text sizes.
struct PillFlowLayout: Layout {
    var spacing: CGFloat = Theme.Spacing.xs

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        return arrange(maxWidth: maxWidth, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(maxWidth: bounds.width, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                anchor: .topLeading,
                proposal: .unspecified
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        let width = maxWidth.isFinite ? min(widest, maxWidth) : widest
        return (CGSize(width: width, height: y + rowHeight), origins)
    }
}

#Preview("Pill styles") {
    let styles: [(String, PIcon?, SelahPillStyle)] = [
        ("Soft", .bookOpen, .soft(.sky)),
        ("Outlined", .church, .outlined(.sage)),
        ("Solid", .check, .solid(.coral)),
        ("Accent", .flame, .accent),
        ("Neutral", .clock, .neutral),
        ("Dark", .pushPin, .neutralDark),
        ("Disabled", .bell, .disabled)
    ]
    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
        ForEach([SelahPillSize.small, .regular], id: \.self) { size in
            PillFlowLayout {
                ForEach(styles.indices, id: \.self) { index in
                    SelahPill(styles[index].0, icon: styles[index].1, style: styles[index].2, size: size)
                }
            }
        }
        PillFlowLayout {
            ForEach(Tone.allCases, id: \.self) { tone in
                SelahPill(tone.name, style: .solid(tone))
            }
        }
        PillFlowLayout {
            ForEach(Tone.allCases, id: \.self) { tone in
                SelahPill(tone.name, style: .outlined(tone))
            }
        }
    }
    .padding(Theme.Spacing.m)
}

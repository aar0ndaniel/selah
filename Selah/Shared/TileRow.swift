import SwiftUI

/// iOS 26 Settings-style list rows: a small rounded-square icon tile, a title, and optional trailing value,
/// count badge and chevron. Use inside `List` / `Form` sections with the system inset grouped style (the system draws
/// the large corner radius, hairline separators and grouped background; nothing is faked here).
///
/// Light mode: `tone.fill` tile with the `tone.ink` glyph. Dark mode: a neutral dark tile with the `tone.ink` glyph.
/// Never use `.sky` (it is blue); use brand/coral/sage/rose/sand/mint/slate (graphite).

/// How a tile row is tinted. `brand` uses the accent pair instead of a tone.
enum TileTone: Hashable, Sendable {
    case brand
    case tone(Tone)

    static let coral = TileTone.tone(.coral)
    static let sage = TileTone.tone(.sage)
    static let rose = TileTone.tone(.rose)
    static let sand = TileTone.tone(.sand)
    static let mint = TileTone.tone(.mint)
    static let graphite = TileTone.tone(.slate)
    static let teal = TileTone.tone(.teal)

    var fill: Color {
        switch self {
        case .brand: return Theme.brandFill
        case .tone(let tone): return tone.fill
        }
    }

    var ink: Color {
        switch self {
        case .brand: return Theme.brandInk
        case .tone(let tone): return tone.ink
        }
    }
}

/// The leading tile alone, for custom rows.
struct TileIcon: View {
    let icon: PIcon
    let tone: TileTone

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 30

    var body: some View {
        PIconView(icon, filled: false, size: 18, relativeTo: .body)
            .foregroundStyle(tone.ink)
            .frame(width: side, height: side)
            .background(
                colorScheme == .dark ? Color(.tertiarySystemFill) : tone.fill,
                in: RoundedRectangle(cornerRadius: side * 0.27, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

/// Tile plus title. Pass it as the label of a `Picker`, `DatePicker` or `Toggle` inside a list row.
struct TileLabel: View {
    let title: String
    let icon: PIcon
    let tone: TileTone
    var destructive = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            TileIcon(icon: icon, tone: destructive ? .rose : tone)
            Text(title)
                .font(.body)
                .foregroundStyle(destructive ? Color.red : Color.primary)
        }
    }
}

/// A tappable or navigable row. Wrap in `NavigationLink` / `Button` yourself; for a `NavigationLink`, also call
/// `.navigationLinkIndicatorVisibility(.hidden)` and set `showsChevron: true` so the Phosphor chevron is the only one.
struct TileRow: View {
    let title: String
    let icon: PIcon
    var tone: TileTone = .brand
    var value: String?
    var badge: Int?
    var showsChevron = false
    var destructive = false

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            TileLabel(title: title, icon: icon, tone: tone, destructive: destructive)
            Spacer(minLength: Theme.Spacing.xs)
            if let value {
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            if let badge, badge > 0 {
                Text("\(badge)")
                    .font(.selahStatSmall)
                    .foregroundStyle(Color(.systemBackground))
                    .padding(.horizontal, Theme.Spacing.xs)
                    .frame(minWidth: 24, minHeight: 24)
                    .background(Theme.accent, in: Capsule())
            }
            if showsChevron {
                PIconView(.caretRight, size: 14, relativeTo: .footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: Theme.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [title]
        if let value { parts.append(value) }
        if let badge, badge > 0 { parts.append("\(badge)") }
        return parts.joined(separator: ", ")
    }
}

/// A row with an on/off switch, tinted with the accent.
struct TileToggleRow: View {
    let title: String
    let icon: PIcon
    var tone: TileTone = .brand
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            TileLabel(title: title, icon: icon, tone: tone)
        }
        .tint(Theme.accent)
        .frame(minHeight: Theme.minTapTarget)
    }
}

#Preview("Tile rows") {
    @Previewable @State var on = true
    NavigationStack {
        List {
            Section {
                TileRow(title: "Meeting days", icon: .calendarBlank, tone: .brand, showsChevron: true)
                TileRow(title: "Notifications", icon: .bell, tone: .coral, value: "On", badge: 2, showsChevron: true)
                TileToggleRow(title: "Reminders", icon: .bellRinging, tone: .sage, isOn: $on)
                TileRow(title: "Delete all data", icon: .trash, destructive: true)
            } header: {
                Text("Section")
            } footer: {
                Text("Footer text sits below the card.")
            }
        }
        .navigationTitle("Tile rows")
    }
}

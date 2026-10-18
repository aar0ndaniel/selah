import SwiftUI

// The sticky note used on the Notes board and in Today's "Recent notes" row.

// MARK: - Pure helpers

/// Layout rules for the board. No UI, so they are unit-tested.
enum StickyStyle {
    /// A slight tilt in degrees, between -1.5 and 1.5. The same seed always gives the same tilt
    /// (FNV-1a, not `hashValue`, which changes on every launch).
    static func rotation(seed: String) -> Double {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return Double(hash % 3001) / 1000 - 1.5
    }

    /// The tilt for a note. Built from what the note says, so it stays the same between launches.
    static func rotation(for item: NoteItem) -> Double {
        rotation(seed: "\(item.kind.rawValue)|\(item.title)|\(Int(item.date.timeIntervalSince1970))")
    }

    /// A calm colour for a book, the same on every launch (a sum of its letters, not `hashValue`).
    /// Sky is left out because the verse of the day uses it.
    static func tone(forBook name: String) -> Tone {
        let pool: [Tone] = [.sage, .coral, .rose, .sand, .slate, .mint]
        var sum = 7
        for scalar in name.unicodeScalars {
            sum = (sum &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        return pool[sum % pool.count]
    }

    /// A rough card height, used only to balance the two columns of the board.
    static func estimatedHeight(for item: NoteItem) -> Double {
        let snippetLines = min(Double(item.snippet.count) / 22, 5)
        let titleLines = min(Double(item.title.count) / 14 + 1, 3)
        return 96 + snippetLines * 17 + titleLines * 20
    }

    /// Spreads cards over `columns` columns, always adding the next card to the shortest column.
    /// Returns, per column, the indices of `heights` in their original order.
    static func split(heights: [Double], columns: Int) -> [[Int]] {
        let count = max(columns, 1)
        var result = Array(repeating: [Int](), count: count)
        var totals = Array(repeating: 0.0, count: count)
        for (index, height) in heights.enumerated() {
            var shortest = 0
            for column in 1..<count where totals[column] < totals[shortest] {
                shortest = column
            }
            result[shortest].append(index)
            totals[shortest] += height
        }
        return result
    }
}

// MARK: - Pill on a coloured card

/// A small pill for use on a tone-filled card. Same shape as `Pill`, but its fill is a translucent page colour,
/// because a pill of the card's own tone would disappear into it.
struct OnCardPill: View {
    let text: String
    var icon: PIcon? = nil
    var tone: Tone

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                PIconView(icon, size: 14, relativeTo: .footnote)
            }
            Text(text)
                .font(.selahLabelSmall.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tone.ink)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sticky note card

struct StickyNoteCard: View {
    enum Size {
        /// Fills its grid column.
        case regular
        /// Wider, for the pinned row.
        case large
        /// Small, for the Recent notes row on Today.
        case mini
    }

    let item: NoteItem
    var size: Size = .regular
    /// The note's rich text. When it contains highlights the snippet shows them (soft mint), otherwise the
    /// plain snippet is used.
    var richSnippet: AttributedString? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var largeWidth: CGFloat = 236
    @ScaledMetric(relativeTo: .body) private var miniWidth: CGFloat = 168
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 132

    private var tone: Tone { item.colour.tone }

    private var titleFont: Font {
        size == .large ? .selahCardTitle : .selahHeadline
    }

    private var snippetLimit: Int {
        switch size {
        case .mini: return 2
        case .regular: return 5
        case .large: return 6
        }
    }

    private var snippetText: Text? {
        if let rich = richSnippet, rich.hasHighlight {
            return Text(rich.snippetPrefix(220).highlightedForDisplay())
        }
        if item.snippet.isEmpty { return nil }
        return Text(item.snippet)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PIconView(.pushPin, filled: true, size: 22, relativeTo: .body)
                .foregroundStyle(tone.ink)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Spacing.xxs)

            OnCardPill(text: item.kind.chipTitle, icon: item.kind.icon, tone: tone)

            Text(item.displayTitle)
                .font(titleFont)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(size == .mini ? 2 : 3)

            if let snippetText {
                snippetText
                    .font(size == .large ? .selahBody : .selahLabel)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(snippetLimit)
            }

            Spacer(minLength: 0)

            Text(item.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.selahLabelSmall)
                .foregroundStyle(tone.inkSecondary)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.s)
        .padding(.bottom, Theme.Spacing.m)
        .frame(width: fixedWidth, alignment: .topLeading)
        .frame(maxWidth: size == .regular ? CGFloat.infinity : nil, minHeight: minHeight, alignment: .topLeading)
        .background(tone.fill, in: shape)
        .overlay(alignment: .top) {
            // Dark mode: every note is the same grey, so a 4pt top band carries the note's colour.
            if colorScheme == .dark {
                shape.fill(tone.swatch)
                    .mask(alignment: .top) { Rectangle().frame(height: 4) }
            }
        }
        .contentShape(shape)
        // Soft shadow in light mode only; on a black page it would be invisible and only add noise.
        .shadow(color: colorScheme == .light ? Color.black.opacity(0.10) : .clear, radius: 6, x: 0, y: 3)
        .rotationEffect(.degrees(reduceMotion ? 0 : StickyStyle.rotation(for: item)))
    }

    private var fixedWidth: CGFloat? {
        switch size {
        case .regular: return nil
        case .large: return largeWidth
        case .mini: return miniWidth
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
    }
}

// MARK: - Display helpers

extension AttributedString {
    /// True when any run carries a highlight.
    var hasHighlight: Bool {
        runs.contains { $0[HighlightIDAttribute.self] != nil }
    }

    /// The first `count` characters, keeping their formatting.
    func snippetPrefix(_ count: Int) -> AttributedString {
        let characters = self.characters
        guard characters.count > count else { return self }
        let end = characters.index(characters.startIndex, offsetBy: count)
        return AttributedString(self[characters.startIndex..<end])
    }
}

extension NoteKind {
    var label: String {
        switch self {
        case .study: return "Study"
        case .service: return "Service"
        case .personal: return "Personal"
        }
    }

    var chipTitle: String {
        switch self {
        case .study: return "Study"
        case .service: return "Services"
        case .personal: return "Personal"
        }
    }

    var icon: PIcon {
        switch self {
        case .study: return .bookOpen
        case .service: return .church
        case .personal: return .userCircle
        }
    }
}

extension NoteItem {
    var displayTitle: String {
        title.isEmpty ? "Untitled note" : title
    }

    /// "Sticky note, Sermon on hope, Services, 12 October, pinned"
    var stickyAccessibilityLabel: String {
        var parts = ["Sticky note", displayTitle, kind.chipTitle]
        parts.append(date.formatted(.dateTime.day().month(.wide)))
        if pinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }
}

#Preview("Sticky notes") {
    let items = [
        NoteItem(
            id: "a", kind: .service, title: "Sermon on hope", snippet: "Hope is an anchor for the soul, sure and steadfast.",
            date: Date(), colour: .sky, pinned: true, verseRefs: []
        ),
        NoteItem(
            id: "b", kind: .study, title: "Philippians 3 · 12 Oct", snippet: "Pressing on toward the goal.",
            date: Date(), colour: .sage, pinned: false, verseRefs: []
        ),
        NoteItem(
            id: "c", kind: .personal, title: "", snippet: "",
            date: Date(), colour: .peach, pinned: false, verseRefs: []
        )
    ]
    ScrollView {
        VStack(spacing: Theme.Spacing.l) {
            ForEach(items) { StickyNoteCard(item: $0) }
            ScrollView(.horizontal) {
                HStack {
                    ForEach(items) { StickyNoteCard(item: $0, size: .mini) }
                }
            }
        }
        .padding(Theme.Spacing.m)
    }
}

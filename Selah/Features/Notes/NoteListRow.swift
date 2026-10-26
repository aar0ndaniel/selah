import SwiftUI

/// A note card: a rounded card with a coloured tile and glyph on the left, a bold title, a two-line snippet and a row
/// of small neutral pills (read time, date, highlights). A pinned card has a soft tint and a pin badge on its tile.
/// Used in the Notes tab, Today's recent notes and search results.
struct NoteCard: View {
    let item: NoteItem
    /// Words in the whole note, for the read time.
    var wordCount: Int
    /// Distinct highlights in the note.
    var highlightCount: Int = 0
    var richSnippet: AttributedString? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 72

    private let radius: CGFloat = 18

    private var snippetText: Text? {
        if let rich = richSnippet, rich.hasHighlight {
            return Text(rich.snippetPrefix(160).highlightedForDisplay())
        }
        if item.snippet.isEmpty { return nil }
        return Text(item.snippet)
    }

    private var tileActivity: MascotActivity {
        switch item.kind {
        case .study: return .reading
        case .service: return .praying
        case .personal: return .writing
        }
    }

    /// Normal cards are neutral; a pinned card gets a soft tint (brand tint in light, raised grey in dark).
    private var cardFill: Color {
        if item.pinned {
            return colorScheme == .dark ? Tone.slate.pillFill : Theme.brandFill
        }
        return Color(.secondarySystemBackground)
    }

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.s))
    }

    var body: some View {
        layout {
            tile

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.displayTitle)
                    .font(.selahCardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let snippetText {
                    // Not .secondary: that grey is about 4:1 on this card; primary at 70% stays above 4.5:1.
                    snippetText
                        .font(.selahLabel)
                        .foregroundStyle(.primary.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                PillFlowLayout(spacing: Theme.Spacing.xs) {
                    SelahPill(
                        "\(NotesStyle.readMinutes(wordCount: wordCount)) min",
                        icon: .clock,
                        style: .neutral
                    )
                    SelahPill(
                        item.date.formatted(.dateTime.day().month(.abbreviated).year()),
                        icon: .calendarBlank,
                        style: .neutral
                    )
                    if highlightCount > 0 {
                        SelahPill(
                            highlightCount == 1 ? "1 highlight" : "\(highlightCount) highlights",
                            icon: .highlighter,
                            style: .soft(.mint)
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardFill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var side: CGFloat {
        // At accessibility sizes the tile stops growing so the text keeps the room.
        typeSize.isAccessibilitySize ? 56 : min(tileSize, 96)
    }

    /// The mascot tile: study reads, service prays, personal writes. Pinned notes keep the pin badge.
    private var tile: some View {
        MascotTile(activity: tileActivity, size: side)
            .overlay(alignment: .topTrailing) {
                if item.pinned {
                    // Push-pin badge.
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 22, height: 22)
                        .overlay {
                            PIconView(.pushPin, filled: true, size: 13, relativeTo: .caption)
                                .foregroundStyle(Theme.accent)
                        }
                        .overlay { Circle().strokeBorder(Color(.separator), lineWidth: 0.5) }
                        .offset(x: 6, y: -6)
                }
            }
    }
}

extension NoteItem {
    /// "Service note, Sermon on hope, 12 October, pinned"
    var listAccessibilityLabel: String {
        var parts = ["\(kind.label) note", displayTitle]
        parts.append(date.formatted(.dateTime.day().month(.wide)))
        if pinned { parts.append("pinned") }
        return parts.joined(separator: ", ")
    }
}

extension AttributedString {
    /// Number of distinct highlights in the text.
    var highlightCount: Int {
        Set(runs.compactMap { $0[HighlightIDAttribute.self] }).count
    }

    /// Words in the text.
    var wordCount: Int {
        String(characters).split(whereSeparator: { $0.isWhitespace }).count
    }
}

#Preview("Note cards") {
    VStack(spacing: Theme.Spacing.s) {
        NoteCard(
            item: NoteItem(
                id: "a", kind: .service, title: "Sermon on hope",
                snippet: "Hope is an anchor for the soul, sure and steadfast. We hold it when the sea is rough.",
                date: Date(), colour: .sky, pinned: true, verseRefs: []
            ),
            wordCount: 640, highlightCount: 2
        )
        NoteCard(
            item: NoteItem(
                id: "b", kind: .study, title: "Philippians 3 \u{00B7} 12 Oct", snippet: "Pressing on toward the goal.",
                date: Date(), colour: .sage, pinned: false, verseRefs: []
            ),
            wordCount: 120
        )
        NoteCard(
            item: NoteItem(
                id: "c", kind: .personal, title: "Prayer list", snippet: "",
                date: Date(), colour: .peach, pinned: false, verseRefs: []
            ),
            wordCount: 30
        )
    }
    .padding(Theme.Spacing.m)
}

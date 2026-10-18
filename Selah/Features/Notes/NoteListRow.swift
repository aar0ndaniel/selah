import SwiftUI

/// A note in the list view: a rounded card with a tone tile and icon on the left, a serif title, a two-line snippet
/// and a row of small pills (kind, date, read time, highlights).
struct NoteListRow: View {
    let item: NoteItem
    /// Words in the whole note, for the read time.
    var wordCount: Int
    /// Distinct highlights in the note.
    var highlightCount: Int = 0
    var richSnippet: AttributedString? = nil

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 56

    private var tone: Tone { item.colour.tone }

    private var snippetText: Text? {
        if let rich = richSnippet, rich.hasHighlight {
            return Text(rich.snippetPrefix(160).highlightedForDisplay())
        }
        if item.snippet.isEmpty { return nil }
        return Text(item.snippet)
    }

    private var tileIcon: PIcon {
        switch item.kind {
        case .study: return .bookOpen
        case .service: return .church
        case .personal: return .note
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            tile

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(item.displayTitle)
                    .font(.selahHeadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let snippetText {
                    // Not .secondary: that grey is about 4:1 on this card; primary at 78% stays above 4.5:1.
                    snippetText
                        .font(.selahLabel)
                        .foregroundStyle(.primary.opacity(0.78))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                PillFlowLayout(spacing: Theme.Spacing.xs) {
                    SelahPill(item.kind.chipTitle, style: .soft(tone))
                    SelahPill(
                        item.date.formatted(.dateTime.day().month(.abbreviated)),
                        icon: .calendarBlank,
                        style: .neutral
                    )
                    SelahPill(
                        "\(StickyStyle.readMinutes(wordCount: wordCount)) min read",
                        icon: .clock,
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var tile: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tone.pillFill)
            .frame(width: tileSize, height: tileSize)
            .overlay {
                PIconView(tileIcon, size: 26, relativeTo: .body)
                    .foregroundStyle(tone.ink)
            }
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

#Preview("List rows") {
    VStack(spacing: Theme.Spacing.s) {
        NoteListRow(
            item: NoteItem(
                id: "a", kind: .service, title: "Sermon on hope",
                snippet: "Hope is an anchor for the soul, sure and steadfast. We hold it when the sea is rough.",
                date: Date(), colour: .sky, pinned: true, verseRefs: []
            ),
            wordCount: 640, highlightCount: 2
        )
        NoteListRow(
            item: NoteItem(
                id: "b", kind: .study, title: "Philippians 3 \u{00B7} 12 Oct", snippet: "Pressing on toward the goal.",
                date: Date(), colour: .sage, pinned: false, verseRefs: []
            ),
            wordCount: 120
        )
        NoteListRow(
            item: NoteItem(
                id: "c", kind: .personal, title: "Prayer list", snippet: "",
                date: Date(), colour: .peach, pinned: false, verseRefs: []
            ),
            wordCount: 30
        )
    }
    .padding(Theme.Spacing.m)
}

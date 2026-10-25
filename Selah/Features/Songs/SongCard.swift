import SwiftUI

extension LibrarySong {
    /// "Lyrics from Hymnary.org" for imported lyrics; nil for lyrics typed by hand.
    var lyricsCredit: String? {
        SongsLogic.creditLine(source: source, externalID: externalID, hasLyrics: hasLyrics)
    }

    /// Value copy for ordering and searching (`SongsLogic`).
    var entry: SongsEntry {
        SongsEntry(
            title: title,
            type: songType,
            hymnNumber: hymnNumber,
            lyricsText: ([refrain] + lyricVerses).joined(separator: "\n"),
            timesSung: timesSung,
            lastSungAt: lastSungAt,
            createdAt: createdAt
        )
    }
}

/// How a song type looks: tile colour and wording. Hymn = brand, chorus = sage, worship = coral.
enum SongsStyle {
    static func tone(for type: SongType) -> TileTone {
        switch type {
        case .hymn: return .brand
        case .chorus: return .sage
        case .worship: return .coral
        }
    }

    /// Chip / picker wording.
    static func name(for type: SongType) -> String {
        SongLibraryLogic.shortTypeName(type)
    }
}

/// A song as a card in the Songs list (same shape as `NoteCard`): a tone tile with a music glyph, the title in
/// Space Grotesk, an optional first line of the lyrics, and small meta pills.
struct SongCard: View {
    let title: String
    let type: SongType
    let hymnNumber: String
    let timesSung: Int
    let hasLyrics: Bool
    var firstLine: String? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 56

    private let radius: CGFloat = 18

    private var tone: TileTone { SongsStyle.tone(for: type) }

    private var number: String {
        type == .hymn ? hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    private var shownTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled song" : trimmed
    }

    private var layout: AnyLayout {
        typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Theme.Spacing.s))
    }

    private var side: CGFloat {
        typeSize.isAccessibilitySize ? 48 : min(tileSize, 72)
    }

    var body: some View {
        layout {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.fill)
                .frame(width: side, height: side)
                .overlay {
                    PIconView(.musicNotes, size: 26, relativeTo: .body)
                        .foregroundStyle(tone.ink)
                }

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(shownTitle)
                    .font(.selahCardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if let firstLine, !firstLine.isEmpty {
                    // Primary at 70% stays above 4.5:1 on the card (same as note snippets).
                    Text(firstLine)
                        .font(.selahLabel)
                        .foregroundStyle(.primary.opacity(0.7))
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                }

                PillFlowLayout(spacing: Theme.Spacing.xs) {
                    if !number.isEmpty {
                        SelahPill("Hymn \(number)", style: .neutral)
                    } else {
                        SelahPill(SongsStyle.name(for: type), style: .neutral)
                    }
                    if timesSung > 0 {
                        SelahPill("Sung \(timesSung)\u{00D7}", icon: .calendarCheck, style: .neutral)
                    }
                    if hasLyrics {
                        SelahPill("Lyrics", icon: .textAlignLeft, style: .soft(.sage))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

#Preview("Song cards") {
    VStack(spacing: Theme.Spacing.s) {
        SongCard(
            title: "Blessed assurance", type: .hymn, hymnNumber: "245", timesSung: 3, hasLyrics: true,
            firstLine: "Blessed assurance, Jesus is mine!"
        )
        SongCard(title: "This is the day", type: .chorus, hymnNumber: "", timesSung: 1, hasLyrics: false)
        SongCard(title: "Alpha and Omega", type: .worship, hymnNumber: "", timesSung: 0, hasLyrics: true)
    }
    .padding(Theme.Spacing.m)
}

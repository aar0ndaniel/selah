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

/// A song as a card in the Songs list: the mascot with a headset, the title on one line (cut short when too
/// long; the full title is on the song page), and one row of pills: the type ("Hymn 212", "Chorus", "Worship")
/// and "Lyrics" when the song has lyrics.
struct SongCard: View {
    let title: String
    let type: SongType
    let hymnNumber: String
    let hasLyrics: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    private let radius: CGFloat = 18

    private var number: String {
        type == .hymn ? hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    private var typeText: String {
        number.isEmpty ? SongsStyle.name(for: type) : "Hymn \(number)"
    }

    private var shownTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled song" : trimmed
    }

    private var tileSide: CGFloat { typeSize.isAccessibilitySize ? 48 : 56 }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            MascotTile(activity: .headset, size: tileSide)

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(shownTitle)
                    .font(.selahCardTitle)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .truncationMode(.tail)

                PillFlowLayout(spacing: Theme.Spacing.xs) {
                    SelahPill(typeText, style: .neutral)
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
        SongCard(title: "Blessed assurance", type: .hymn, hymnNumber: "245", hasLyrics: true)
        SongCard(title: "This is the day that the Lord has made, we will rejoice and be glad in it", type: .chorus, hymnNumber: "", hasLyrics: false)
        SongCard(title: "Alpha and Omega", type: .worship, hymnNumber: "", hasLyrics: true)
    }
    .padding(Theme.Spacing.m)
}

import Foundation
import SwiftData

/// Plain value copy of a song's identity (title, type, hymn number), for matching without SwiftData.
struct SongKey: Sendable, Equatable {
    var title: String
    var type: SongType
    var hymnNumber: String

    init(title: String = "", type: SongType = .hymn, hymnNumber: String = "") {
        self.title = title
        self.type = type
        self.hymnNumber = hymnNumber
    }
}

/// Pure rules for the song library: how titles compare, which library song a logged song links to, suggestions.
/// Unit tested.
enum SongLibraryLogic {
    /// Lowercased, accents and punctuation removed, spaces collapsed: "Great Is Thy Faithfulness!" and
    /// "great is thy  faithfulness" are the same song.
    static func normalisedTitle(_ title: String) -> String {
        let folded = title.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars)
            .split(whereSeparator: { $0 == " " })
            .joined(separator: " ")
    }

    static func normalisedNumber(_ number: String) -> String {
        number.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// The library song a logged song should link to, as an index into `candidates`, or nil when none matches.
    ///
    /// Same type and the same normalised title wins. A hymn logged with a number but no title links to the library
    /// hymn with that number.
    static func matchIndex(for key: SongKey, in candidates: [SongKey]) -> Int? {
        let title = normalisedTitle(key.title)
        if !title.isEmpty {
            return candidates.firstIndex { $0.type == key.type && normalisedTitle($0.title) == title }
        }
        let number = normalisedNumber(key.hymnNumber)
        guard key.type == .hymn, !number.isEmpty else { return nil }
        return candidates.firstIndex { $0.type == .hymn && normalisedNumber($0.hymnNumber) == number }
    }

    /// Library songs to suggest while a title is typed, as indices into `candidates`, best first.
    ///
    /// Titles that start with the typed words come first, then titles that contain them; within each group songs of
    /// `preferredType` come first, then A to Z. A hymn number typed as the query matches that hymn. Songs whose title
    /// is exactly the query (and same type) are left out: they are already what was typed.
    static func suggestions(
        for query: String,
        preferredType: SongType? = nil,
        in candidates: [SongKey],
        limit: Int = 4
    ) -> [Int] {
        let wanted = normalisedTitle(query)
        guard !wanted.isEmpty, limit > 0 else { return [] }
        var ranked: [(index: Int, rank: Int)] = []
        for (index, candidate) in candidates.enumerated() {
            let title = normalisedTitle(candidate.title)
            guard !title.isEmpty else { continue }
            if title == wanted && (preferredType == nil || candidate.type == preferredType) { continue }
            let rank: Int
            if title.hasPrefix(wanted) {
                rank = 0
            } else if title.contains(wanted) {
                rank = 1
            } else if candidate.type == .hymn, normalisedNumber(candidate.hymnNumber) == wanted {
                rank = 0
            } else {
                continue
            }
            let typeRank = (preferredType == nil || candidate.type == preferredType) ? 0 : 1
            ranked.append((index, rank * 2 + typeRank))
        }
        return ranked
            .sorted { lhs, rhs in
                if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
                let l = normalisedTitle(candidates[lhs.index].title)
                let r = normalisedTitle(candidates[rhs.index].title)
                if l != r { return l < r }
                return lhs.index < rhs.index
            }
            .prefix(limit)
            .map { $0.index }
    }

    /// "Hymn", "Chorus" or "Worship song".
    static func typeName(_ type: SongType) -> String {
        switch type {
        case .hymn: return "Hymn"
        case .chorus: return "Chorus"
        case .worship: return "Worship song"
        }
    }

    /// Short segment label: "Hymn", "Chorus", "Worship".
    static func shortTypeName(_ type: SongType) -> String {
        switch type {
        case .hymn: return "Hymn"
        case .chorus: return "Chorus"
        case .worship: return "Worship"
        }
    }

    /// One line for a song: "Hymn 212, Great is thy faithfulness", "Hymn 212", or just the title.
    /// Only hymns show a number.
    static func displayName(type: SongType, hymnNumber: String, title: String) -> String {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let number = type == .hymn ? hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        switch (number.isEmpty, name.isEmpty) {
        case (false, false): return "Hymn \(number), \(name)"
        case (false, true): return "Hymn \(number)"
        default: return name
        }
    }

    /// A library song made only by logging (no lyrics, no longer linked to any service song) can go: it was a
    /// typo or a title that was later changed. Songs added by hand or imported always stay.
    static func isDisposable(source: LibrarySongSource, linkedCount: Int, hasLyrics: Bool) -> Bool {
        source == .logged && linkedCount == 0 && !hasLyrics
    }
}

/// Keeps service songs linked to the song library. Runs on the main actor with the view's model context.
@MainActor
enum SongLibrary {
    static func allSongs(in context: ModelContext) -> [LibrarySong] {
        (try? context.fetch(FetchDescriptor<LibrarySong>())) ?? []
    }

    /// Links a song part to the library song with the same title and type, creating one (source `.logged`) when
    /// there is none. A part with no title (and no hymn number match) is unlinked. A library song left behind
    /// with nothing linked and no lyrics is deleted. Returns the linked song.
    @discardableResult
    static func link(_ part: ServicePart, in context: ModelContext, library: [LibrarySong]? = nil) -> LibrarySong? {
        guard part.kind == .song else { return nil }
        let previous = part.librarySong
        let key = SongKey(title: part.title, type: part.songType, hymnNumber: part.hymnNumber)

        // Still the same song: nothing to change.
        if let previous, SongLibraryLogic.matchIndex(for: key, in: [previous.key]) != nil {
            fillMissing(previous, from: part)
            refreshLastSung(previous, including: part)
            return previous
        }

        let songs = library ?? allSongs(in: context)
        let target: LibrarySong?
        if let index = SongLibraryLogic.matchIndex(for: key, in: songs.map { $0.key }) {
            target = songs[index]
        } else if !SongLibraryLogic.normalisedTitle(part.title).isEmpty {
            let created = LibrarySong(
                title: part.title.trimmingCharacters(in: .whitespacesAndNewlines),
                songType: part.songType,
                hymnNumber: part.songType == .hymn ? part.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : "",
                source: .logged
            )
            context.insert(created)
            target = created
        } else {
            target = nil
        }

        part.librarySong = target
        if let target {
            fillMissing(target, from: part)
            refreshLastSung(target, including: part)
        }
        if let previous, previous !== target {
            removeIfDisposable(previous, in: context, ignoring: part)
        }
        return target
    }

    /// The user picked a library song from the suggestions: the part takes its title, type and hymn number.
    static func adopt(_ song: LibrarySong, for part: ServicePart, in context: ModelContext) {
        let previous = part.librarySong
        part.title = song.title
        part.songType = song.songType
        if song.songType == .hymn, !song.hymnNumber.isEmpty {
            part.hymnNumber = song.hymnNumber
        }
        part.librarySong = song
        refreshLastSung(song, including: part)
        if let previous, previous !== song {
            removeIfDisposable(previous, in: context, ignoring: part)
        }
    }

    /// Call before deleting a song part, so a library song it alone created goes with it.
    static func partWillBeDeleted(_ part: ServicePart, in context: ModelContext) {
        guard let song = part.librarySong else { return }
        part.librarySong = nil
        removeIfDisposable(song, in: context, ignoring: part)
    }

    /// Sets `lastSungAt` to the latest service date among the song's linked parts (plus `part`, which may have
    /// just been linked before SwiftData updated the inverse list).
    static func refreshLastSung(_ song: LibrarySong, including part: ServicePart? = nil) {
        var linked = song.parts
        if let part, !linked.contains(where: { $0 === part }) { linked.append(part) }
        song.lastSungAt = linked.compactMap { $0.service?.date }.max()
    }

    /// A logged hymn learns its number from the first service that records one.
    private static func fillMissing(_ song: LibrarySong, from part: ServicePart) {
        let number = part.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if song.songType == .hymn, song.hymnNumber.isEmpty, part.songType == .hymn, !number.isEmpty {
            song.hymnNumber = number
        }
    }

    private static func removeIfDisposable(_ song: LibrarySong, in context: ModelContext, ignoring part: ServicePart) {
        let others = song.parts.filter { $0 !== part }
        if SongLibraryLogic.isDisposable(source: song.source, linkedCount: others.count, hasLyrics: song.hasLyrics) {
            context.delete(song)
        } else {
            song.lastSungAt = others.compactMap { $0.service?.date }.max()
        }
    }
}

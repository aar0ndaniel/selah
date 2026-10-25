import Foundation

// Pure rules for the Songs tab: sorting, filtering, searching, the A to Z sections, the delete guard, the credit
// line, and the verse sequence for the lyrics practice view. No SwiftData, no UI. Unit tested (SongsTests).

/// How the song list is ordered.
enum SongsSort: String, CaseIterable, Identifiable, Sendable {
    /// Title A to Z, with section letters.
    case alphabetical
    /// Latest service first (`lastSungAt`), then newest added.
    case recentlyLogged
    /// Sung the most times first.
    case mostSung

    var id: String { rawValue }

    var title: String {
        switch self {
        case .alphabetical: return "A\u{2013}Z"
        case .recentlyLogged: return "Recently logged"
        case .mostSung: return "Most sung"
        }
    }
}

/// The type chips above the list.
enum SongsFilter: String, CaseIterable, Identifiable, Hashable, Sendable {
    case all, hymns, choruses, worship

    var id: String { rawValue }

    var chipTitle: String {
        switch self {
        case .all: return "All"
        case .hymns: return "Hymns"
        case .choruses: return "Choruses"
        case .worship: return "Worship"
        }
    }

    func includes(_ type: SongType) -> Bool {
        switch self {
        case .all: return true
        case .hymns: return type == .hymn
        case .choruses: return type == .chorus
        case .worship: return type == .worship
        }
    }
}

/// Plain value copy of a library song, for ordering and searching without SwiftData.
struct SongsEntry: Sendable, Equatable {
    var title: String
    var type: SongType
    var hymnNumber: String
    /// All lyrics as one text (verses and refrain), used only for searching.
    var lyricsText: String
    var timesSung: Int
    var lastSungAt: Date?
    var createdAt: Date

    init(
        title: String,
        type: SongType = .hymn,
        hymnNumber: String = "",
        lyricsText: String = "",
        timesSung: Int = 0,
        lastSungAt: Date? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 0)
    ) {
        self.title = title
        self.type = type
        self.hymnNumber = hymnNumber
        self.lyricsText = lyricsText
        self.timesSung = timesSung
        self.lastSungAt = lastSungAt
        self.createdAt = createdAt
    }
}

/// One lettered group in the A to Z list: the letter and indices into the entries array.
struct SongsSection: Sendable, Equatable {
    var letter: String
    var indices: [Int]
}

/// Whether a song may be deleted from the Songs tab.
enum SongsDeleteDecision: Sendable, Equatable {
    case allowed
    /// The song is in at least one service. `title` is the alert title ("This song is in 3 services"),
    /// `message` says what to do.
    case blocked(title: String, message: String)
}

enum SongsLogic {
    /// Letters are sections A to Z; titles starting with a digit or symbol go under this.
    static let otherLetter = "#"

    // MARK: Titles

    /// The text titles are ordered by: lowercased, accents and punctuation gone ("'Twas grace" sorts as "twas grace").
    static func sortKey(_ title: String) -> String {
        SongLibraryLogic.normalisedTitle(title)
    }

    /// "A" to "Z" for a title starting with a letter (accents folded, so "Ecole" and "\u{00C9}cole" are both "E").
    /// Another script keeps its own capital letter. A title starting with a digit or symbol is "#".
    static func sectionLetter(for title: String) -> String {
        guard let first = sortKey(title).first, first.isLetter else { return otherLetter }
        return String(first).uppercased()
    }

    /// Letters first (A to Z), then digits and symbols; each group by `sortKey`.
    private static func alphabeticalPrecedes(_ lhs: SongsEntry, _ rhs: SongsEntry) -> Bool? {
        let leftKey = sortKey(lhs.title)
        let rightKey = sortKey(rhs.title)
        let leftIsLetter = sectionLetter(for: lhs.title) != otherLetter
        let rightIsLetter = sectionLetter(for: rhs.title) != otherLetter
        if leftIsLetter != rightIsLetter { return leftIsLetter }
        if leftKey != rightKey { return leftKey < rightKey }
        return nil
    }

    // MARK: Order

    /// Indices into `entries`, filtered by type and search text and ordered by `sort`. Ties always fall back to
    /// A to Z, then to the original position, so the order never jumps around.
    static func order(
        _ entries: [SongsEntry],
        sort: SongsSort,
        filter: SongsFilter = .all,
        query: String = ""
    ) -> [Int] {
        let wanted = fold(query)
        let tokens = wanted.split(whereSeparator: { $0.isWhitespace }).map { String($0) }

        let kept = entries.indices.filter { index in
            let entry = entries[index]
            guard filter.includes(entry.type) else { return false }
            guard !tokens.isEmpty else { return true }
            let number = entry.type == .hymn ? entry.hymnNumber : ""
            let haystack = fold([entry.title, number, entry.lyricsText].joined(separator: "\n"))
            return tokens.allSatisfy { haystack.contains($0) }
        }

        return kept.sorted { left, right in
            let lhs = entries[left]
            let rhs = entries[right]
            switch sort {
            case .alphabetical:
                break
            case .recentlyLogged:
                switch (lhs.lastSungAt, rhs.lastSungAt) {
                case let (l?, r?) where l != r: return l > r
                case (.some, .none): return true
                case (.none, .some): return false
                default: break
                }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
            case .mostSung:
                if lhs.timesSung != rhs.timesSung { return lhs.timesSung > rhs.timesSung }
            }
            if let result = alphabeticalPrecedes(lhs, rhs) { return result }
            return left < right
        }
    }

    /// Groups already ordered indices (A to Z order) into letter sections, "#" last.
    static func sections(_ entries: [SongsEntry], ordered: [Int]) -> [SongsSection] {
        var groups: [String: [Int]] = [:]
        for index in ordered {
            groups[sectionLetter(for: entries[index].title), default: []].append(index)
        }
        let letters = groups.keys.sorted { lhs, rhs in
            if lhs == otherLetter { return false }
            if rhs == otherLetter { return true }
            return lhs < rhs
        }
        return letters.map { SongsSection(letter: $0, indices: groups[$0] ?? []) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Delete guard

    /// A song that is in a service stays: deleting it would leave that service's song unlinked from the library.
    static func deleteDecision(serviceCount: Int) -> SongsDeleteDecision {
        guard serviceCount > 0 else { return .allowed }
        let services = serviceCount == 1 ? "1 service" : "\(serviceCount) services"
        return .blocked(
            title: "This song is in \(services)",
            message: serviceCount == 1
                ? "Take it out of that service first, then delete it here."
                : "Take it out of those services first, then delete it here."
        )
    }

    // MARK: Credit

    /// "Lyrics from Hymnary.org" for lyrics brought in from Hymnary; nil for lyrics the user typed.
    static func creditLine(source: LibrarySongSource, externalID: String?, hasLyrics: Bool) -> String? {
        guard hasLyrics, source == .imported, let id = externalID,
              !id.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return "Lyrics from Hymnary.org"
    }

    // MARK: Text for lists

    /// The first non-empty line of the first verse (or of the refrain when there are no verses), for a row's snippet.
    static func firstLine(verses: [String], refrain: String) -> String? {
        let texts = verses + [refrain]
        for text in texts {
            let line = text
                .split(whereSeparator: { $0.isNewline })
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }
            if let line { return line }
        }
        return nil
    }

    /// Verses with surrounding blank space removed and empty ones dropped (what gets saved).
    static func cleanedVerses(_ verses: [String]) -> [String] {
        verses
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// "Hymn 212", the type name, plus "Sung 3\u{00D7}" and "Lyrics" as one VoiceOver sentence for a row.
    static func rowAccessibilityLabel(
        title: String,
        type: SongType,
        hymnNumber: String,
        timesSung: Int,
        hasLyrics: Bool
    ) -> String {
        var parts = [SongLibraryLogic.displayName(type: type, hymnNumber: hymnNumber, title: title)]
        if type != .hymn { parts.append(SongLibraryLogic.typeName(type)) }
        if timesSung > 0 { parts.append(timesSung == 1 ? "sung once" : "sung \(timesSung) times") }
        if hasLyrics { parts.append("has lyrics") }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Lyrics practice

/// One step of the practice view: a verse and the refrain that follows it.
struct LyricsPracticeBlock: Sendable, Equatable, Identifiable {
    /// 1-based verse number; nil for a refrain-only song.
    var verseNumber: Int?
    var text: String
    /// The refrain sung after this verse, when the song has one.
    var refrain: String?

    var id: Int { (verseNumber ?? 0) }
}

enum LyricsPracticeLogic {
    /// One block per non-empty verse, each followed by the refrain. A song with only a refrain is one block.
    static func blocks(verses: [String], refrain: String) -> [LyricsPracticeBlock] {
        let cleanRefrain = refrain.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanVerses = SongsLogic.cleanedVerses(verses)
        guard !cleanVerses.isEmpty else {
            guard !cleanRefrain.isEmpty else { return [] }
            return [LyricsPracticeBlock(verseNumber: nil, text: cleanRefrain, refrain: nil)]
        }
        return cleanVerses.enumerated().map { offset, verse in
            LyricsPracticeBlock(
                verseNumber: offset + 1,
                text: verse,
                refrain: cleanRefrain.isEmpty ? nil : cleanRefrain
            )
        }
    }

    /// "Verse 2 of 6", or "Refrain" for a refrain-only song.
    static func chipText(blocks: [LyricsPracticeBlock], index: Int) -> String {
        guard blocks.indices.contains(index) else { return "" }
        guard let number = blocks[index].verseNumber else { return "Refrain" }
        return "Verse \(number) of \(blocks.count)"
    }

    /// The index after a step forwards or back, held inside the song.
    static func moved(from index: Int, by step: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return min(max(index + step, 0), count - 1)
    }
}

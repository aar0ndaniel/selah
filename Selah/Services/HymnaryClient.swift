import Foundation

// Hymnary.org lookup for the Songs tab (endpoints tested 25 Oct 2026, see docs/HYMN-LYRICS-RESEARCH.md):
//
//   search : GET https://hymnary.org/search?qu=<title>%20in:texts&export=csv     (CSV, one row per hymn text)
//   lyrics : GET https://hymnary.org/api/fulltext/<textAuthNumber>               (JSON array of printings)
//
// Licensing rule (owner decision): lyrics are only used from a printing whose `displayPermissions` is "all".
// Anything else is never shown or stored; the user types the lyrics instead.
//
// The parsing lives in `HymnaryParsing` as pure, nonisolated functions with unit tests. The network calls in
// `HymnaryClient` are thin and are not unit tested.

// MARK: - Values

/// One hymn text found by a title search.
struct HymnarySearchResult: Sendable, Equatable, Hashable, Identifiable {
    var displayTitle: String
    var firstLine: String
    var textTitle: String
    var refrainFirstLine: String
    /// Hymnary's id for the text; the key for the lyrics lookup and stored as `LibrarySong.externalID`.
    var textAuthNumber: String
    var authors: String
    var meter: String
    var totalInstances: Int

    var id: String { textAuthNumber }

    init(
        displayTitle: String = "",
        firstLine: String = "",
        textTitle: String = "",
        refrainFirstLine: String = "",
        textAuthNumber: String,
        authors: String = "",
        meter: String = "",
        totalInstances: Int = 0
    ) {
        self.displayTitle = displayTitle
        self.firstLine = firstLine
        self.textTitle = textTitle
        self.refrainFirstLine = refrainFirstLine
        self.textAuthNumber = textAuthNumber
        self.authors = authors
        self.meter = meter
        self.totalInstances = totalInstances
    }

    /// The title to put in the song title field.
    var suggestedTitle: String {
        for candidate in [displayTitle, textTitle, firstLine] {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return ""
    }

    /// "Amazing grace! how sweet the sound · John Newton": first line and author under the title.
    var detailLine: String {
        let first = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let author = authors.trimmingCharacters(in: .whitespacesAndNewlines)
        let shownFirst = first.caseInsensitiveCompare(suggestedTitle) == .orderedSame ? "" : first
        return [shownFirst, author].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }
}

/// Lyrics ready to put in a song: verses (number removed, verse 1 first) and an optional refrain.
struct SongsHymnLyrics: Sendable, Equatable {
    var verses: [String]
    var refrain: String?
    /// Title of the printing the text came from (a hymnal name).
    var sourceHymnal: String
    /// The hymn's number in that printing.
    var number: String

    init(verses: [String], refrain: String? = nil, sourceHymnal: String = "", number: String = "") {
        self.verses = verses
        self.refrain = refrain
        self.sourceHymnal = sourceHymnal
        self.number = number
    }
}

/// The verses and refrain found in one block of printed text.
struct HymnaryParsedLyrics: Sendable, Equatable {
    var verses: [String]
    var refrain: String?
}

/// One printing of a hymn text in the fulltext JSON. Every field is read leniently (string, number or missing).
struct HymnaryFulltextEntry: Sendable, Equatable, Decodable {
    var title: String
    var hymnalID: String
    var number: String
    var text: String
    var displayPermissions: String
    var date: String
    var classifications: String

    init(
        title: String = "",
        hymnalID: String = "",
        number: String = "",
        text: String = "",
        displayPermissions: String = "",
        date: String = "",
        classifications: String = ""
    ) {
        self.title = title
        self.hymnalID = hymnalID
        self.number = number
        self.text = text
        self.displayPermissions = displayPermissions
        self.date = date
        self.classifications = classifications
    }

    private enum CodingKeys: String, CodingKey {
        case title, hymnalID, number, text, displayPermissions, date, classifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = container.lenientString(forKey: .title)
        hymnalID = container.lenientString(forKey: .hymnalID)
        number = container.lenientString(forKey: .number)
        text = container.lenientString(forKey: .text)
        displayPermissions = container.lenientString(forKey: .displayPermissions)
        date = container.lenientString(forKey: .date)
        classifications = container.lenientString(forKey: .classifications)
    }
}

private extension KeyedDecodingContainer {
    func lenientString(forKey key: Key) -> String {
        if let value = try? decode(String.self, forKey: key) { return value }
        if let value = try? decode(Int.self, forKey: key) { return String(value) }
        if let value = try? decode(Double.self, forKey: key) { return String(value) }
        if let value = try? decode([String].self, forKey: key) { return value.joined(separator: ", ") }
        return ""
    }
}

// MARK: - Errors

enum HymnaryError: Error, Sendable, Equatable, LocalizedError {
    /// No connection, a timeout or a bad status.
    case unreachable
    /// A reply that is not what we expected.
    case unreadable

    var errorDescription: String? { Self.friendlyMessage }

    /// Shown inline under the title field.
    static let friendlyMessage = "Couldn\u{2019}t reach Hymnary. You can type the lyrics instead."
}

// MARK: - Parsing (pure)

enum HymnaryParsing {
    /// Search results kept after sorting.
    static let resultLimit = 8

    // MARK: CSV

    /// Parses CSV text into rows of fields: quoted fields, commas and line breaks inside quotes, `""` for a quote,
    /// LF / CRLF / CR row ends and a leading byte-order mark. Blank lines are skipped.
    nonisolated static func parseCSV(_ text: String) -> [[String]] {
        let quote: Unicode.Scalar = "\""
        let comma: Unicode.Scalar = ","
        let lineFeed: Unicode.Scalar = "\n"
        let carriageReturn: Unicode.Scalar = "\r"
        let byteOrderMark: Unicode.Scalar = "\u{FEFF}"

        let scalars = Array(text.unicodeScalars)
        var rows: [[String]] = []
        var row: [String] = []
        var field = String.UnicodeScalarView()
        var inQuotes = false
        var index = scalars.first == byteOrderMark ? 1 : 0

        func finishRow() {
            row.append(String(field))
            field = String.UnicodeScalarView()
            // A line with nothing on it is not a row.
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while index < scalars.count {
            let scalar = scalars[index]
            if inQuotes {
                if scalar == quote {
                    if index + 1 < scalars.count, scalars[index + 1] == quote {
                        field.append(quote)
                        index += 1
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else if scalar == quote {
                inQuotes = true
            } else if scalar == comma {
                row.append(String(field))
                field = String.UnicodeScalarView()
            } else if scalar == carriageReturn {
                if index + 1 < scalars.count, scalars[index + 1] == lineFeed { index += 1 }
                finishRow()
            } else if scalar == lineFeed {
                finishRow()
            } else {
                field.append(scalar)
            }
            index += 1
        }
        if !field.isEmpty || !row.isEmpty { finishRow() }
        return rows
    }

    // MARK: Search results

    /// Results from the search CSV: the header row names the columns (displayTitle, firstLine, textTitle,
    /// refrainFirstLine, textAuthNumber, authors, meter, totalInstances; others are ignored). Rows with no
    /// textAuthNumber are dropped, repeats of one text are merged, and the top `limit` by `totalInstances` are
    /// returned, most used first.
    nonisolated static func parseSearchResults(csv: String, limit: Int = resultLimit) -> [HymnarySearchResult] {
        let rows = parseCSV(csv)
        guard let header = rows.first else { return [] }
        var columns: [String: Int] = [:]
        for (position, name) in header.enumerated() {
            let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if columns[key] == nil { columns[key] = position }
        }
        guard let idColumn = columns["textauthnumber"] else { return [] }

        func value(_ row: [String], _ name: String) -> String {
            guard let position = columns[name], position < row.count else { return "" }
            return row[position].trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var seen = Set<String>()
        var results: [HymnarySearchResult] = []
        for row in rows.dropFirst() {
            let id = idColumn < row.count ? row[idColumn].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            guard !id.isEmpty, !seen.contains(id) else { continue }
            let result = HymnarySearchResult(
                displayTitle: value(row, "displaytitle"),
                firstLine: value(row, "firstline"),
                textTitle: value(row, "texttitle"),
                refrainFirstLine: value(row, "refrainfirstline"),
                textAuthNumber: id,
                authors: value(row, "authors"),
                meter: value(row, "meter"),
                totalInstances: Int(value(row, "totalinstances")) ?? 0
            )
            guard !result.suggestedTitle.isEmpty else { continue }
            seen.insert(id)
            results.append(result)
        }
        // Stable: equal counts keep the order Hymnary gave.
        let ranked = results.enumerated().sorted { lhs, rhs in
            if lhs.element.totalInstances != rhs.element.totalInstances {
                return lhs.element.totalInstances > rhs.element.totalInstances
            }
            return lhs.offset < rhs.offset
        }
        return ranked.prefix(max(0, limit)).map { $0.element }
    }

    // MARK: Fulltext JSON

    nonisolated static func decodeFulltext(_ data: Data) throws -> [HymnaryFulltextEntry] {
        do {
            return try JSONDecoder().decode([HymnaryFulltextEntry].self, from: data)
        } catch {
            throw HymnaryError.unreadable
        }
    }

    /// True when the printing may be displayed: `displayPermissions` is "all".
    nonisolated static func mayDisplay(_ entry: HymnaryFulltextEntry) -> Bool {
        entry.displayPermissions.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "all"
            && !entry.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The printing to use: the first one that may be displayed, preferring one whose text has numbered verses.
    /// Nil when no printing may be displayed (lyrics are then never shown).
    nonisolated static func displayableEntry(in entries: [HymnaryFulltextEntry]) -> HymnaryFulltextEntry? {
        let allowed = entries.filter { mayDisplay($0) }
        return allowed.first { hasNumberedVerses($0.text) } ?? allowed.first
    }

    /// Lyrics from a fulltext reply, or nil when nothing may be displayed or nothing could be read from the text.
    nonisolated static func lyrics(from entries: [HymnaryFulltextEntry]) -> SongsHymnLyrics? {
        guard let entry = displayableEntry(in: entries) else { return nil }
        let parsed = parseLyrics(entry.text)
        guard !parsed.verses.isEmpty || parsed.refrain != nil else { return nil }
        return SongsHymnLyrics(
            verses: parsed.verses,
            refrain: parsed.refrain,
            sourceHymnal: entry.title.trimmingCharacters(in: .whitespacesAndNewlines),
            number: entry.number.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    // MARK: Lyrics text

    /// Line breaks as plain "\n". The fulltext text uses "\n\r\n" inside a verse and "\n\r\n\n" between verses,
    /// so "\n\r\n" and "\r\n" both become one "\n" (a verse break is then a blank line) and a lone "\r" is a "\n".
    nonisolated static func normaliseLineBreaks(_ text: String) -> String {
        let lineFeed: Unicode.Scalar = "\n"
        let carriageReturn: Unicode.Scalar = "\r"
        let scalars = Array(text.unicodeScalars)
        var output = String.UnicodeScalarView()
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if scalar == lineFeed, index + 2 < scalars.count,
               scalars[index + 1] == carriageReturn, scalars[index + 2] == lineFeed {
                output.append(lineFeed)
                index += 3
            } else if scalar == carriageReturn {
                output.append(lineFeed)
                index += (index + 1 < scalars.count && scalars[index + 1] == lineFeed) ? 2 : 1
            } else {
                output.append(scalar)
                index += 1
            }
        }
        return String(output)
    }

    /// "1. Amazing grace" gives (1, "Amazing grace"); "2)" gives (2, ""); a line with no leading number gives nil.
    nonisolated static func numberedLine(_ line: String) -> (number: Int, rest: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        var digits = ""
        var cursor = trimmed.startIndex
        while cursor < trimmed.endIndex, trimmed[cursor].isASCII, trimmed[cursor].isNumber, digits.count < 3 {
            digits.append(trimmed[cursor])
            cursor = trimmed.index(after: cursor)
        }
        guard !digits.isEmpty, let number = Int(digits), cursor < trimmed.endIndex else { return nil }
        let mark = trimmed[cursor]
        guard mark == "." || mark == ")" else { return nil }
        let rest = trimmed[trimmed.index(after: cursor)...].trimmingCharacters(in: .whitespaces)
        // "1.5 million" is not a verse number ("1.Amazing" still is).
        if let first = trimmed[trimmed.index(after: cursor)...].first, first.isNumber { return nil }
        return (number, rest)
    }

    /// True when some line starts with a verse number ("1. ").
    nonisolated static func hasNumberedVerses(_ text: String) -> Bool {
        normaliseLineBreaks(text)
            .split(separator: "\n", omittingEmptySubsequences: true)
            .contains { numberedLine(String($0)) != nil }
    }

    /// A line that only names the refrain ("Refrain", "Chorus:", "Refrain."), or starts one ("Chorus: Glory"):
    /// returns the text after the label (empty when the line is only the label). Nil when it is not a label.
    nonisolated static func refrainLabel(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "[]()")))
        let lowered = trimmed.lowercased()
        for label in ["refrain", "chorus"] where lowered.hasPrefix(label) {
            let rest = trimmed.dropFirst(label.count)
            if rest.isEmpty { return "" }
            guard let next = rest.first, ":.-\u{2013})]".contains(next) else { return nil }
            return rest
                .drop(while: { ":.-\u{2013})] ".contains($0) })
                .trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// Splits printed hymn text into verses and a refrain.
    ///
    /// 1. Line breaks are normalised and the text is cut into blocks on blank lines.
    /// 2. A block starting "1. " is a verse; the number is removed.
    /// 3. A block starting "Refrain" or "Chorus" is the refrain (the label is removed). A label line inside a verse
    ///    block splits it: the lines after it are the refrain.
    /// 4. In a numbered hymn, the first other block is the refrain (a later copy of it is skipped, a later different
    ///    block is a verse). With no numbers, a block that appears more than once is the refrain, and the verses are
    ///    the distinct other blocks in order.
    nonisolated static func parseLyrics(_ text: String) -> HymnaryParsedLyrics {
        let blocks = textBlocks(in: normaliseLineBreaks(text))
        guard !blocks.isEmpty else { return HymnaryParsedLyrics(verses: [], refrain: nil) }

        enum Kind { case verse, refrain, plain }
        var parsed: [(kind: Kind, text: String)] = []

        for block in blocks {
            var lines = block
            var kind: Kind = .plain
            if let first = lines.first, let numbered = numberedLine(first) {
                kind = .verse
                lines[0] = numbered.rest
                lines.removeAll(where: { $0.isEmpty })
            } else if let first = lines.first, let rest = refrainLabel(first) {
                kind = .refrain
                lines[0] = rest
                lines.removeAll(where: { $0.isEmpty })
            }

            // A label in the middle of a block: verse lines, then the refrain.
            if kind != .refrain,
               let split = lines.indices.dropFirst().first(where: { refrainLabel(lines[$0]) != nil }),
               let rest = refrainLabel(lines[split]) {
                var refrainLines = Array(lines[(split + 1)...])
                if !rest.isEmpty { refrainLines.insert(rest, at: 0) }
                let head = Array(lines[..<split])
                if !head.isEmpty { parsed.append((kind, head.joined(separator: "\n"))) }
                if !refrainLines.isEmpty { parsed.append((.refrain, refrainLines.joined(separator: "\n"))) }
                continue
            }
            guard !lines.isEmpty else { continue }
            parsed.append((kind, lines.joined(separator: "\n")))
        }

        let hasNumbers = parsed.contains { $0.kind == .verse }
        let labelled = parsed.first { $0.kind == .refrain }?.text
        var refrain = labelled
        var verses: [String] = []

        if hasNumbers {
            for item in parsed {
                switch item.kind {
                case .verse:
                    verses.append(item.text)
                case .refrain:
                    break
                case .plain:
                    if refrain == nil {
                        refrain = item.text
                    } else if same(item.text, refrain ?? "") {
                        continue
                    } else {
                        verses.append(item.text)
                    }
                }
            }
        } else {
            // No verse numbers: a repeated block is the refrain.
            let others = parsed.filter { $0.kind != .refrain }
            var counts: [String: Int] = [:]
            for item in others { counts[fold(item.text), default: 0] += 1 }
            if refrain == nil {
                refrain = others.first { counts[fold($0.text), default: 0] > 1 }?.text
            }
            var kept = Set<String>()
            for item in others {
                let key = fold(item.text)
                if let refrain, key == fold(refrain) { continue }
                if kept.contains(key) { continue }
                kept.insert(key)
                verses.append(item.text)
            }
        }
        return HymnaryParsedLyrics(verses: verses, refrain: refrain)
    }

    /// Groups the non-blank lines of `text` into blocks separated by one or more blank lines.
    private nonisolated static func textBlocks(in text: String) -> [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                if !current.isEmpty { result.append(current) }
                current = []
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty { result.append(current) }
        return result
    }

    private nonisolated static func fold(_ text: String) -> String {
        text.split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
    }

    private nonisolated static func same(_ lhs: String, _ rhs: String) -> Bool {
        fold(lhs) == fold(rhs)
    }

    // MARK: URLs

    /// `https://hymnary.org/search?qu=<title>%20in:texts&export=csv`. Nil when the title is empty.
    nonisolated static func searchURL(title: String) -> URL? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://hymnary.org/search?qu=\(encoded)%20in:texts&export=csv")
    }

    /// `https://hymnary.org/api/fulltext/<id>`. Nil when the id is empty or has odd characters.
    nonisolated static func fulltextURL(textAuthNumber: String) -> URL? {
        let trimmed = textAuthNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard !trimmed.isEmpty, let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return URL(string: "https://hymnary.org/api/fulltext/\(encoded)")
    }
}

// MARK: - Client

/// Talks to hymnary.org. Not unit tested (network); everything it returns goes through `HymnaryParsing`.
struct HymnaryClient: Sendable {
    static let userAgent = "Tehila iOS app (personal use)"
    static let timeout: TimeInterval = 10

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Top matches for a hymn title, most used first (at most 8).
    func search(title: String) async throws -> [HymnarySearchResult] {
        guard let url = HymnaryParsing.searchURL(title: title) else { return [] }
        let data = try await fetch(url)
        let csv = String(decoding: data, as: UTF8.self)
        return HymnaryParsing.parseSearchResults(csv: csv)
    }

    /// Lyrics for a hymn text, or nil when no printing may be displayed.
    func lyrics(textAuthNumber: String) async throws -> SongsHymnLyrics? {
        guard let url = HymnaryParsing.fulltextURL(textAuthNumber: textAuthNumber) else { return nil }
        let data = try await fetch(url)
        let entries = try HymnaryParsing.decodeFulltext(data)
        return HymnaryParsing.lyrics(from: entries)
    }

    private func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: Self.timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw HymnaryError.unreachable
            }
            return data
        } catch let error as HymnaryError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw HymnaryError.unreachable
        }
    }
}

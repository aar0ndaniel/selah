import Foundation
import SwiftData

/// Which kind of record a note on the Notes tab comes from.
enum NoteKind: String, CaseIterable, Hashable, Sendable {
    case study
    case service
    case personal
}

/// One card on the Notes tab. A plain value built from a study entry, a service or a personal note.
struct NoteItem: Identifiable, Hashable, Sendable {
    let id: String
    let kind: NoteKind
    let title: String
    /// Plain text, no formatting.
    let snippet: String
    let date: Date
    let colour: NoteColour
    let pinned: Bool
    /// For example "Philippians 4:6-7" or "Philippians 2".
    let verseRefs: [String]
}

/// Searching, filtering and ordering for the Notes tab. Pure functions, no SwiftData.
enum NotesIndex {
    // MARK: Filter

    static func filter(_ items: [NoteItem], kind: NoteKind?, query: String) -> [NoteItem] {
        let byKind: [NoteItem]
        if let kind {
            byKind = items.filter { $0.kind == kind }
        } else {
            byKind = items
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return byKind }
        return byKind.filter { matches($0, query: trimmed) }
    }

    // MARK: Order

    /// Newest first.
    static func sorted(_ items: [NoteItem]) -> [NoteItem] {
        items.sorted { left, right in
            if left.date != right.date { return left.date > right.date }
            return left.id < right.id
        }
    }

    /// Pinned notes first, then the rest. Each group is newest first.
    static func sections(_ items: [NoteItem]) -> (pinned: [NoteItem], others: [NoteItem]) {
        (
            pinned: sorted(items.filter { $0.pinned }),
            others: sorted(items.filter { !$0.pinned })
        )
    }

    // MARK: Matching

    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func matches(_ item: NoteItem, query: String) -> Bool {
        let foldedQuery = fold(query)
        let words = fold(item.title) + "\n" + fold(item.snippet)
        let refs = item.verseRefs.map { fold($0) }

        // "Phil 4" or "Philippians 4:6": match verse references by book prefix and chapter/verse.
        if let wanted = parseQuery(foldedQuery) {
            if refs.contains(where: { refMatches($0, wanted) }) { return true }
            return words.contains(foldedQuery)
        }

        // Otherwise every word of the query must appear in the title, the snippet or a reference.
        let haystack = ([words] + refs).joined(separator: "\n")
        let tokens = foldedQuery.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        return tokens.allSatisfy { haystack.contains($0) }
    }

    private struct WantedRef {
        let book: String
        let chapter: Int
        let verseStart: Int?
        let verseEnd: Int?
    }

    private struct Numbers {
        let chapter: Int
        let start: Int?
        let end: Int?
    }

    /// Splits "1 john 3:16" into book "1 john", chapter 3, verse 16. Nil if it does not look like a reference.
    private static func parseQuery(_ query: String) -> WantedRef? {
        let parts = query.split(whereSeparator: { $0.isWhitespace }).map { String($0) }
        guard parts.count >= 2, let last = parts.last, let numbers = parseNumbers(last) else { return nil }
        let book = parts.dropLast().joined(separator: " ")
        guard book.contains(where: { $0.isLetter }) else { return nil }
        return WantedRef(book: book, chapter: numbers.chapter, verseStart: numbers.start, verseEnd: numbers.end)
    }

    private static func parseNumbers(_ text: String) -> Numbers? {
        let halves = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false).map { String($0) }
        guard let first = halves.first, let chapter = Int(first) else { return nil }
        guard halves.count == 2 else { return Numbers(chapter: chapter, start: nil, end: nil) }
        let range = halves[1]
            .split(whereSeparator: { $0 == "-" || $0 == "\u{2013}" })
            .map { String($0) }
        guard let startText = range.first, let start = Int(startText) else { return nil }
        let end = range.count > 1 ? (Int(range[1]) ?? start) : start
        return Numbers(chapter: chapter, start: start, end: end)
    }

    private static func refMatches(_ ref: String, _ wanted: WantedRef) -> Bool {
        guard let space = ref.lastIndex(of: " ") else { return false }
        let book = String(ref[ref.startIndex..<space])
        let numbersText = String(ref[ref.index(after: space)...])
        guard book.hasPrefix(wanted.book), let have = parseNumbers(numbersText), have.chapter == wanted.chapter else {
            return false
        }
        guard let wantedStart = wanted.verseStart, let wantedEnd = wanted.verseEnd else { return true }
        // A whole-chapter reference ("Philippians 2") matches any verse in that chapter.
        guard let haveStart = have.start, let haveEnd = have.end else { return true }
        return wantedStart <= haveEnd && wantedEnd >= haveStart
    }
}

// MARK: - Building items from stored records

extension NoteItem {
    /// Stable for the life of the app run; the view uses it to find the record again when a card is tapped.
    @MainActor
    static func makeID(_ kind: NoteKind, _ model: any PersistentModel) -> String {
        "\(kind.rawValue)-\(model.persistentModelID.hashValue)"
    }

    @MainActor
    init(study entry: StudyEntry) {
        let book = entry.plan?.bookName ?? ""
        let chapter = book.isEmpty ? "Study" : "\(book) \(entry.chapter)"
        var refs: [String] = []
        if !book.isEmpty { refs.append("\(book) \(entry.chapter)") }
        if let verse = entry.bestVerse { refs.append(verse.reference) }
        var snippet = NoteItem.plainText(entry.note)
        if snippet.isEmpty, let verse = entry.bestVerse { snippet = NoteItem.collapse(verse.textSnapshot) }
        self.init(
            id: NoteItem.makeID(.study, entry),
            kind: .study,
            title: "\(chapter) \u{00B7} \(entry.date.formatted(.dateTime.day().month(.abbreviated)))",
            snippet: snippet,
            date: entry.date,
            colour: .sage,
            pinned: false,
            verseRefs: refs
        )
    }

    @MainActor
    init(service: Service) {
        let title: String
        if !service.sermonTitle.isEmpty {
            title = service.sermonTitle
        } else if !service.gatheringName.isEmpty {
            title = service.gatheringName
        } else {
            title = "Service"
        }
        var snippet = [NoteItem.plainText(service.sermonNote), NoteItem.plainText(service.classNote)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if snippet.isEmpty, !service.sermonist.isEmpty { snippet = "Taught by \(service.sermonist)" }
        self.init(
            id: NoteItem.makeID(.service, service),
            kind: .service,
            title: title,
            snippet: snippet,
            date: service.date,
            colour: .sky,
            pinned: false,
            verseRefs: service.verses.map { $0.reference }
        )
    }

    @MainActor
    init(personal note: PersonalNote) {
        self.init(
            id: NoteItem.makeID(.personal, note),
            kind: .personal,
            title: note.title,
            snippet: NoteItem.plainText(note.body),
            date: note.updatedAt,
            colour: note.colour,
            pinned: note.pinned,
            verseRefs: note.verses.map { $0.reference }
        )
    }

    static func plainText(_ text: AttributedString) -> String {
        collapse(String(text.characters))
    }

    static func collapse(_ text: String) -> String {
        let joined = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return joined.count > 280 ? String(joined.prefix(280)) : joined
    }
}

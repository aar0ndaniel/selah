import Foundation

/// A parsed Bible reference. `verseStart == nil` means the whole chapter.
struct BibleReference: Hashable, Sendable {
    var bookID: Int
    var bookName: String
    var chapter: Int
    var verseStart: Int?
    var verseEnd: Int?

    /// For example "Philippians 4:6-7", "John 3:16" or "Psalms 23".
    var displayString: String {
        guard let start = verseStart else { return "\(bookName) \(chapter)" }
        if let end = verseEnd, end > start {
            return "\(bookName) \(chapter):\(start)-\(end)"
        }
        return "\(bookName) \(chapter):\(start)"
    }
}

/// Turns typed text such as "Phil 4:6-7" into a `BibleReference`. No database involved.
struct ReferenceParser: Sendable {
    init() {}

    private enum Token: Equatable {
        case number(Int)
        case colon
        case dash
        case space
    }

    func parse(_ input: String) -> BibleReference? {
        let text = Self.normalise(input)
        let parts = Self.split(text)
        guard !parts.book.isEmpty,
              let bookID = BibleBooks.bookID(forAlias: parts.book),
              let bookName = BibleBooks.name(for: bookID),
              let chapterCount = BibleBooks.chapterCount(for: bookID),
              let tokens = Self.tokenise(parts.tail),
              !tokens.isEmpty
        else { return nil }

        let singleChapter = chapterCount == 1

        func number(_ index: Int) -> Int? {
            guard index < tokens.count else { return nil }
            if case .number(let n) = tokens[index] { return n }
            return nil
        }
        func isChapterVerseSeparator(_ index: Int) -> Bool {
            guard index < tokens.count else { return false }
            return tokens[index] == .colon || tokens[index] == .space
        }
        func isDash(_ index: Int) -> Bool {
            index < tokens.count && tokens[index] == .dash
        }

        var chapter = 0
        var start: Int?
        var end: Int?

        switch tokens.count {
        case 1:
            guard let n = number(0) else { return nil }
            if singleChapter {
                chapter = 1
                start = n
            } else {
                chapter = n
            }
        case 3:
            if let c = number(0), isChapterVerseSeparator(1), let v = number(2) {
                chapter = c
                start = v
            } else if singleChapter, let a = number(0), isDash(1), let b = number(2) {
                chapter = 1
                start = a
                end = b
            } else {
                return nil
            }
        case 5:
            guard let c = number(0), isChapterVerseSeparator(1), let v = number(2), isDash(3), let v2 = number(4) else {
                return nil
            }
            chapter = c
            start = v
            end = v2
        default:
            return nil
        }

        guard chapter >= 1, chapter <= chapterCount else { return nil }
        if let s = start {
            guard s >= 1 else { return nil }
            if let e = end {
                guard e >= s else { return nil }
            }
        }
        if let e = end, e == start { end = nil }
        return BibleReference(bookID: bookID, bookName: bookName, chapter: chapter, verseStart: start, verseEnd: end)
    }

    /// Book names that match what has been typed so far, in canonical order. "1 j" gives ["1 John"].
    func suggestions(for prefix: String) -> [String] {
        let text = Self.normalise(prefix)
        guard !text.isEmpty else { return [] }
        let parts = Self.split(text)
        let typed = BibleBooks.key(parts.book.isEmpty ? text : parts.book)
        guard !typed.isEmpty else { return [] }
        var ids = Set<Int>()
        for entry in BibleBooks.suggestionKeys where entry.key.hasPrefix(typed) {
            ids.insert(entry.id)
        }
        return ids.sorted().compactMap { BibleBooks.name(for: $0) }
    }

    // MARK: Helpers

    private static func normalise(_ input: String) -> String {
        var s = input.lowercased()
        for dash in ["\u{2013}", "\u{2014}", "\u{2012}", "\u{2212}", "\u{2010}", "\u{2011}"] {
            s = s.replacingOccurrences(of: dash, with: "-")
        }
        s = s.replacingOccurrences(of: "\u{00A0}", with: " ")
        let junk = CharacterSet(charactersIn: " \t\n.,;:!?-")
        return s.trimmingCharacters(in: junk)
    }

    /// Splits "1 jn 1:9" into book "1 jn" and tail " 1:9" by peeling digits and separators off the end.
    private static func split(_ text: String) -> (book: String, tail: String) {
        let chars = Array(text)
        var index = chars.count
        while index > 0 {
            let ch = chars[index - 1]
            let isDigit = ch.isASCII && ch.isNumber
            if isDigit || ch == ":" || ch == "." || ch == "-" || ch == " " {
                index -= 1
            } else {
                break
            }
        }
        let book = String(chars[0..<index]).trimmingCharacters(in: .whitespaces)
        let tail = String(chars[index...])
        return (book, tail)
    }

    private static func lastIsNumber(_ tokens: [Token]) -> Bool {
        if let last = tokens.last, case .number = last { return true }
        return false
    }

    private static func tokenise(_ tail: String) -> [Token]? {
        var tokens: [Token] = []
        var pendingSpace = false
        let chars = Array(tail)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch.isASCII && ch.isNumber {
                var value = 0
                var digits = 0
                while i < chars.count, chars[i].isASCII, let d = chars[i].wholeNumberValue {
                    value = value * 10 + d
                    digits += 1
                    i += 1
                }
                if digits > 3 { return nil }
                if pendingSpace && lastIsNumber(tokens) { tokens.append(.space) }
                pendingSpace = false
                tokens.append(.number(value))
                continue
            }
            switch ch {
            case " ":
                pendingSpace = true
            case ":":
                tokens.append(.colon)
                pendingSpace = false
            case ".":
                if lastIsNumber(tokens) { tokens.append(.colon) }
                pendingSpace = false
            case "-":
                tokens.append(.dash)
                pendingSpace = false
            default:
                return nil
            }
            i += 1
        }
        return tokens
    }
}

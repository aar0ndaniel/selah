import Foundation

// Rich text formatting for notes: a Foundation-only model (no UIKit), so it can be unit-tested and reused.
//
// Stored form (AttributedString, encoded by `RichTextCoding`):
//   - bold / italic / strikethrough: Foundation `inlinePresentationIntent`
//   - underline: `SelahUnderlineAttribute`
//   - block style: `BlockStyleAttribute` on every run of a paragraph ("h", "ul", "ol", "quote")
//   - highlight: `HighlightIDAttribute`
// List paragraphs also start with a real text prefix ("• " or "1. "), so plain text keeps the list markers.
//
// Text view form (NSAttributedString): the same facts as custom keys (`selahBold` ... `selahBlock`), plus fonts and
// paragraph styles derived from them by `HighlightBridge.styled`. Fonts are never read back, so a heading's
// semibold or a quote's italic is never mistaken for a user's bold or italic.

// MARK: - Attribute keys (text view side)

extension NSAttributedString.Key {
    static var selahHighlightID: NSAttributedString.Key { NSAttributedString.Key("selah.highlightID") }
    static var selahBold: NSAttributedString.Key { NSAttributedString.Key("selah.bold") }
    static var selahItalic: NSAttributedString.Key { NSAttributedString.Key("selah.italic") }
    static var selahUnderline: NSAttributedString.Key { NSAttributedString.Key("selah.underline") }
    static var selahStrikethrough: NSAttributedString.Key { NSAttributedString.Key("selah.strikethrough") }
    static var selahBlock: NSAttributedString.Key { NSAttributedString.Key("selah.block") }
}

// MARK: - Styles

/// Paragraph-level style. Raw values are what is stored in `BlockStyleAttribute`.
enum BlockStyle: String, CaseIterable, Sendable {
    case heading = "h"
    case bullet = "ul"
    case numbered = "ol"
    case quote = "quote"

    var isList: Bool { self == .bullet || self == .numbered }
}

/// Character-level style.
enum InlineStyle: CaseIterable, Sendable {
    case bold, italic, underline, strikethrough

    var key: NSAttributedString.Key {
        switch self {
        case .bold: return .selahBold
        case .italic: return .selahItalic
        case .underline: return .selahUnderline
        case .strikethrough: return .selahStrikethrough
        }
    }
}

/// Everything that can differ between two stretches of a note.
struct RichFormat: Equatable, Sendable {
    var bold = false
    var italic = false
    var underline = false
    var strikethrough = false
    var block: BlockStyle?
    var highlightID: String?

    init() {}

    func has(_ style: InlineStyle) -> Bool {
        switch style {
        case .bold: return bold
        case .italic: return italic
        case .underline: return underline
        case .strikethrough: return strikethrough
        }
    }

    mutating func set(_ style: InlineStyle, _ on: Bool) {
        switch style {
        case .bold: bold = on
        case .italic: italic = on
        case .underline: underline = on
        case .strikethrough: strikethrough = on
        }
    }

    /// Reads the model keys of a text view attribute dictionary. Everything else (fonts, colours) is ignored.
    init(attributes: [NSAttributedString.Key: Any]) {
        bold = (attributes[.selahBold] as? Bool) ?? false
        italic = (attributes[.selahItalic] as? Bool) ?? false
        underline = (attributes[.selahUnderline] as? Bool) ?? false
        strikethrough = (attributes[.selahStrikethrough] as? Bool) ?? false
        if let raw = attributes[.selahBlock] as? String {
            block = BlockStyle(rawValue: raw)
        }
        highlightID = attributes[.selahHighlightID] as? String
    }

    /// The model keys only, as text view attributes.
    var attributes: [NSAttributedString.Key: Any] {
        var result: [NSAttributedString.Key: Any] = [:]
        if bold { result[.selahBold] = true }
        if italic { result[.selahItalic] = true }
        if underline { result[.selahUnderline] = true }
        if strikethrough { result[.selahStrikethrough] = true }
        if let block { result[.selahBlock] = block.rawValue }
        if let highlightID { result[.selahHighlightID] = highlightID }
        return result
    }
}

/// A stretch of text with one format. Adjacent segments always differ in format.
struct RichSegment: Equatable, Sendable {
    var string: String
    var format: RichFormat
}

// MARK: - AttributedString <-> segments <-> NSAttributedString (model keys only)

enum RichTextFormatting {
    /// Splits stored text into stretches with one format each. Adjacent equal stretches are merged, so the result
    /// depends only on words and formatting, never on how the runs happen to be split.
    static func segments(of text: AttributedString) -> [RichSegment] {
        var result: [RichSegment] = []
        for run in text.runs {
            let piece = String(text[run.range].characters)
            guard !piece.isEmpty else { continue }
            var format = RichFormat()
            let intent = run.inlinePresentationIntent ?? []
            format.bold = intent.contains(.stronglyEmphasized)
            format.italic = intent.contains(.emphasized)
            format.strikethrough = intent.contains(.strikethrough)
            format.underline = run[SelahUnderlineAttribute.self] ?? false
            if let raw = run[BlockStyleAttribute.self] {
                format.block = BlockStyle(rawValue: raw)
            }
            format.highlightID = run[HighlightIDAttribute.self]
            append(piece, format, to: &result)
        }
        return result
    }

    /// Builds stored text from segments.
    static func attributedString(from segments: [RichSegment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments where !segment.string.isEmpty {
            var piece = AttributedString(segment.string)
            let all = piece.startIndex..<piece.endIndex
            let format = segment.format
            var intent: InlinePresentationIntent = []
            if format.bold { intent.insert(.stronglyEmphasized) }
            if format.italic { intent.insert(.emphasized) }
            if format.strikethrough { intent.insert(.strikethrough) }
            if !intent.isEmpty {
                piece[all].inlinePresentationIntent = intent
            }
            if format.underline {
                piece[all][SelahUnderlineAttribute.self] = true
            }
            if let block = format.block {
                piece[all][BlockStyleAttribute.self] = block.rawValue
            }
            if let id = format.highlightID {
                piece[all][HighlightIDAttribute.self] = id
            }
            result.append(piece)
        }
        return result
    }

    /// Words only: formatting is dropped, list markers are kept because they are real text.
    static func plainText(of text: AttributedString) -> String {
        String(text.characters)
    }

    /// Text with list numbers corrected (for example after text was pasted or imported).
    static func renumbered(_ text: AttributedString) -> AttributedString {
        let model = RichTextBridge.model(from: segments(of: text))
        var selection = NSRange(location: 0, length: 0)
        RichTextOps.normalize(model, selection: &selection)
        return attributedString(from: RichTextBridge.segments(from: model))
    }

    fileprivate static func append(_ piece: String, _ format: RichFormat, to result: inout [RichSegment]) {
        if let last = result.last, last.format == format {
            result[result.count - 1].string += piece
        } else {
            result.append(RichSegment(string: piece, format: format))
        }
    }
}

/// Model-level NSAttributedString (custom keys only, no fonts).
enum RichTextBridge {
    static func model(from segments: [RichSegment]) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for segment in segments where !segment.string.isEmpty {
            result.append(NSAttributedString(string: segment.string, attributes: segment.format.attributes))
        }
        return result
    }

    static func segments(from text: NSAttributedString) -> [RichSegment] {
        var result: [RichSegment] = []
        let string = NSString(string: text.string)
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
            RichTextFormatting.append(string.substring(with: range), RichFormat(attributes: attributes), to: &result)
        }
        return result
    }
}

// MARK: - Editing operations (NSMutableAttributedString, model keys only)

/// Pure editing operations used by the note editor. They only touch the model keys and list prefixes; the editor
/// re-applies fonts afterwards. Selections are `NSRange`s in UTF-16 units and are moved along with the edits.
enum RichTextOps {
    // MARK: Prefixes

    static func listPrefix(for style: BlockStyle, number: Int) -> String {
        switch style {
        case .bullet: return "\u{2022} "
        case .numbered: return "\(number). "
        case .heading, .quote: return ""
        }
    }

    /// Length of the list prefix at the start of `paragraph` (a bullet and a space, or digits, a dot and a space).
    /// Zero for other styles or when the prefix is missing.
    static func prefixLength(of style: BlockStyle, in string: NSString, paragraph: NSRange) -> Int {
        let start = paragraph.location
        let end = paragraph.location + paragraph.length
        switch style {
        case .bullet:
            guard end - start >= 2, string.character(at: start) == 0x2022, string.character(at: start + 1) == 0x20 else {
                return 0
            }
            return 2
        case .numbered:
            var index = start
            while index < end, string.character(at: index) >= 0x30, string.character(at: index) <= 0x39 {
                index += 1
            }
            guard index > start, index + 1 < end,
                  string.character(at: index) == 0x2E, string.character(at: index + 1) == 0x20 else {
                return 0
            }
            return index + 2 - start
        case .heading, .quote:
            return 0
        }
    }

    // MARK: Paragraphs

    private static func isSeparator(_ character: unichar) -> Bool {
        character == 0x0A || character == 0x0D || character == 0x2029
    }

    /// Every paragraph, each including its trailing newline. A final empty paragraph is included when the text
    /// is empty or ends with a newline (that is where the caret sits on a new line).
    static func paragraphRanges(in string: NSString) -> [NSRange] {
        var result: [NSRange] = []
        let length = string.length
        var location = 0
        while location < length {
            let range = string.paragraphRange(for: NSRange(location: location, length: 0))
            if range.length == 0 { break }
            result.append(range)
            location = range.location + range.length
        }
        if length == 0 || isSeparator(string.character(at: length - 1)) {
            result.append(NSRange(location: length, length: 0))
        }
        return result
    }

    /// The paragraphs a selection touches. A caret belongs to one paragraph; a selection ending right after a
    /// newline does not reach into the next paragraph.
    static func paragraphs(in string: NSString, covering selection: NSRange) -> [NSRange] {
        let all = paragraphRanges(in: string)
        var effective = selection
        let end = selection.location + selection.length
        if selection.length > 0, end <= string.length, isSeparator(string.character(at: end - 1)) {
            effective.length -= 1
        }
        let low = effective.location
        let high = effective.location + effective.length
        return all.filter { paragraph in
            let paragraphEnd = paragraph.location + paragraph.length
            if effective.length == 0 {
                return paragraph.location <= low && (low < paragraphEnd || paragraph == all.last)
            }
            return paragraph.location < high && low < paragraphEnd
        }
    }

    /// End of a paragraph's words (before the trailing newline).
    static func contentEnd(of paragraph: NSRange, in string: NSString) -> Int {
        var end = paragraph.location + paragraph.length
        while end > paragraph.location, isSeparator(string.character(at: end - 1)) {
            end -= 1
        }
        return end
    }

    /// The paragraph's block style, read from its last word character (so text typed at the end of a paragraph
    /// decides, not the character before its first letter). Nil for an empty paragraph.
    static func block(ofParagraph paragraph: NSRange, in text: NSAttributedString) -> BlockStyle? {
        guard paragraph.length > 0 else { return nil }
        let string = NSString(string: text.string)
        var index = paragraph.location + paragraph.length - 1
        if index > paragraph.location, isSeparator(string.character(at: index)) {
            index -= 1
        }
        guard let raw = text.attribute(.selahBlock, at: index, effectiveRange: nil) as? String else { return nil }
        return BlockStyle(rawValue: raw)
    }

    /// The parts of `range` that are the user's words: no list prefixes, no newlines.
    static func contentRanges(in text: NSAttributedString, covering range: NSRange) -> [NSRange] {
        let string = NSString(string: text.string)
        var result: [NSRange] = []
        for paragraph in paragraphRanges(in: string) where paragraph.length > 0 {
            var prefix = 0
            if let found = block(ofParagraph: paragraph, in: text) {
                prefix = prefixLength(of: found, in: string, paragraph: paragraph)
            }
            let start = max(paragraph.location + prefix, range.location)
            let end = min(contentEnd(of: paragraph, in: string), range.location + range.length)
            if end > start {
                result.append(NSRange(location: start, length: end - start))
            }
        }
        return result
    }

    // MARK: Selection bookkeeping

    /// Moves `selection` after `range` was replaced by text of `newLength`.
    static func mapSelection(_ selection: inout NSRange, replacing range: NSRange, withLength newLength: Int) {
        func map(_ point: Int) -> Int {
            if point < range.location { return point }
            if range.length == 0 { return point + newLength }
            if point == range.location { return point }
            if point >= range.location + range.length { return point + newLength - range.length }
            return range.location + newLength
        }
        let start = map(selection.location)
        let end = map(selection.location + selection.length)
        selection = NSRange(location: start, length: max(0, end - start))
    }

    // MARK: Inline styles

    /// True when every word character in `range` has the style (and there is at least one).
    static func inlineState(_ style: InlineStyle, in text: NSAttributedString, range: NSRange) -> Bool {
        let ranges = contentRanges(in: text, covering: range)
        guard !ranges.isEmpty else { return false }
        for piece in ranges {
            var all = true
            text.enumerateAttribute(style.key, in: piece, options: []) { value, _, stop in
                if (value as? Bool) != true {
                    all = false
                    stop.pointee = true
                }
            }
            if !all { return false }
        }
        return true
    }

    static func setInline(_ style: InlineStyle, _ on: Bool, in text: NSMutableAttributedString, range: NSRange) {
        for piece in contentRanges(in: text, covering: range) {
            if on {
                text.addAttribute(style.key, value: true, range: piece)
            } else {
                text.removeAttribute(style.key, range: piece)
            }
        }
    }

    /// Turns the style on for the whole range, or off when it is already on everywhere. Returns the new state.
    @discardableResult
    static func toggleInline(_ style: InlineStyle, in text: NSMutableAttributedString, range: NSRange) -> Bool {
        let turnOn = !inlineState(style, in: text, range: range)
        setInline(style, turnOn, in: text, range: range)
        return turnOn
    }

    // MARK: Block styles

    /// True when every paragraph the selection touches has the style.
    static func blockState(_ style: BlockStyle, in text: NSAttributedString, selection: NSRange) -> Bool {
        let string = NSString(string: text.string)
        let touched = paragraphs(in: string, covering: selection)
        guard !touched.isEmpty else { return false }
        return touched.allSatisfy { block(ofParagraph: $0, in: text) == style }
    }

    /// Gives every touched paragraph the style, or removes it when they all have it already. List styles add or
    /// remove their text prefix. Returns the style now in force (nil when removed). Numbers are fixed by `normalize`.
    @discardableResult
    static func toggleBlock(_ style: BlockStyle, in text: NSMutableAttributedString, selection: inout NSRange) -> BlockStyle? {
        let snapshot = NSString(string: text.string)
        let touched = paragraphs(in: snapshot, covering: selection)
        let existing = touched.map { block(ofParagraph: $0, in: text) }
        let target: BlockStyle? = existing.allSatisfy({ $0 == style }) ? nil : style

        for index in touched.indices.reversed() {
            var paragraph = touched[index]
            if let old = existing[index], old.isList {
                let length = prefixLength(of: old, in: snapshot, paragraph: paragraph)
                if length > 0 {
                    let removed = NSRange(location: paragraph.location, length: length)
                    text.deleteCharacters(in: removed)
                    mapSelection(&selection, replacing: removed, withLength: 0)
                    paragraph.length -= length
                }
            }
            if paragraph.length > 0 {
                if let target {
                    text.addAttribute(.selahBlock, value: target.rawValue, range: paragraph)
                } else {
                    text.removeAttribute(.selahBlock, range: paragraph)
                }
            }
            if let target, target.isList {
                let prefix = NSAttributedString(
                    string: listPrefix(for: target, number: 1),
                    attributes: [.selahBlock: target.rawValue]
                )
                let spot = NSRange(location: paragraph.location, length: 0)
                text.insert(prefix, at: spot.location)
                mapSelection(&selection, replacing: spot, withLength: prefix.length)
            }
        }
        normalize(text, selection: &selection)
        return target
    }

    // MARK: Normalising

    /// Makes block styles and list prefixes consistent: one block style per paragraph (from its last word
    /// character), every list paragraph starts with its marker, and numbered items count 1, 2, 3 ... without gaps.
    /// Returns true when anything changed.
    @discardableResult
    static func normalize(_ text: NSMutableAttributedString, selection: inout NSRange) -> Bool {
        struct Item {
            let paragraph: NSRange
            let block: BlockStyle?
            let number: Int
        }
        let snapshot = NSString(string: text.string)
        var items: [Item] = []
        var counter = 0
        for paragraph in paragraphRanges(in: snapshot) {
            let found = block(ofParagraph: paragraph, in: text)
            counter = found == .numbered ? counter + 1 : 0
            items.append(Item(paragraph: paragraph, block: found, number: counter))
        }

        var changed = false
        for item in items.reversed() {
            var paragraph = item.paragraph
            if let style = item.block, style.isList {
                let wanted = listPrefix(for: style, number: item.number)
                let existing = prefixLength(of: style, in: snapshot, paragraph: paragraph)
                let current = existing > 0
                    ? snapshot.substring(with: NSRange(location: paragraph.location, length: existing))
                    : ""
                if current != wanted {
                    let range = NSRange(location: paragraph.location, length: existing)
                    let replacement = NSAttributedString(string: wanted, attributes: [.selahBlock: style.rawValue])
                    text.replaceCharacters(in: range, with: replacement)
                    mapSelection(&selection, replacing: range, withLength: replacement.length)
                    paragraph.length += replacement.length - existing
                    changed = true
                }
            }
            if paragraph.length > 0 {
                var uniform = true
                text.enumerateAttribute(.selahBlock, in: paragraph, options: []) { value, _, stop in
                    if (value as? String) != item.block?.rawValue {
                        uniform = false
                        stop.pointee = true
                    }
                }
                if !uniform {
                    if let style = item.block {
                        text.addAttribute(.selahBlock, value: style.rawValue, range: paragraph)
                    } else {
                        text.removeAttribute(.selahBlock, range: paragraph)
                    }
                    changed = true
                }
            }
        }
        return changed
    }
}

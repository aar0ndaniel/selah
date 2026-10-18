import Foundation

/// Pure helpers for highlight IDs inside an `AttributedString`.
/// A highlight is a run carrying `HighlightIDAttribute`; its value matches `NoteComment.highlightID`.
enum HighlightLogic {
    /// A stretch of text that either has no highlight or belongs to one highlight.
    struct Segment: Equatable, Sendable {
        var string: String
        var highlightID: String?
    }

    static func newID() -> String {
        UUID().uuidString
    }

    /// Marks `range` as part of the highlight `id`.
    static func apply(id: String, to range: Range<AttributedString.Index>, in text: inout AttributedString) {
        text[range][HighlightIDAttribute.self] = id
    }

    /// Removes the highlight `id` from every run that carries it.
    static func removeHighlight(id: String, from text: inout AttributedString) {
        // Look the run up again each time so indices are never stale.
        while let range = text.runs.first(where: { $0[HighlightIDAttribute.self] == id })?.range {
            text[range][HighlightIDAttribute.self] = nil
        }
    }

    /// Every highlight ID present in the text.
    static func ids(in text: AttributedString) -> Set<String> {
        Set(text.runs.compactMap { $0[HighlightIDAttribute.self] })
    }

    /// Highlight IDs in reading order, without repeats.
    static func orderedIDs(in text: AttributedString) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for run in text.runs {
            if let id = run[HighlightIDAttribute.self], seen.insert(id).inserted {
                result.append(id)
            }
        }
        return result
    }

    /// Comment IDs whose highlighted words are no longer in the text.
    static func orphanedIDs(commentIDs: [String], in text: AttributedString) -> Set<String> {
        Set(commentIDs).subtracting(ids(in: text))
    }

    /// Splits the text into plain and highlighted stretches. Adjacent stretches with the same ID are merged,
    /// so two texts with the same words and highlights give equal segments whatever other attributes they hold.
    static func segments(of text: AttributedString) -> [Segment] {
        var result: [Segment] = []
        for run in text.runs {
            let piece = String(text[run.range].characters)
            guard !piece.isEmpty else { continue }
            let id = run[HighlightIDAttribute.self]
            if let last = result.last, last.highlightID == id {
                result[result.count - 1].string += piece
            } else {
                result.append(Segment(string: piece, highlightID: id))
            }
        }
        return result
    }

    /// Builds rich text from segments.
    static func attributedString(from segments: [Segment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments where !segment.string.isEmpty {
            var piece = AttributedString(segment.string)
            if let id = segment.highlightID {
                piece[piece.startIndex..<piece.endIndex][HighlightIDAttribute.self] = id
            }
            result.append(piece)
        }
        return result
    }
}

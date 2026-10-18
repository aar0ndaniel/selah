import SwiftUI

extension AttributedString {
    /// For read-only display (for example `Text(entry.note.highlightedForDisplay())`).
    ///
    /// Bold, italic and strikethrough are Foundation attributes that `Text` draws by itself. This adds what `Text`
    /// cannot derive: the soft mint background of every highlighted run, underline, New York semibold for headings
    /// and italic secondary text for quotes. None of it is stored with the note: it is always derived from the
    /// stored facts (highlight ID, underline flag, block style), so the stored text stays small and safe to decode.
    /// List markers are real text, so lists already read correctly.
    func highlightedForDisplay() -> AttributedString {
        struct Edit {
            let range: Range<AttributedString.Index>
            let highlighted: Bool
            let underline: Bool
            let block: BlockStyle?
            let intent: InlinePresentationIntent
        }

        var result = self
        var edits: [Edit] = []
        for run in result.runs {
            let highlighted = run[HighlightIDAttribute.self] != nil
            let underline = run[SelahUnderlineAttribute.self] ?? false
            var block: BlockStyle?
            if let raw = run[BlockStyleAttribute.self] {
                block = BlockStyle(rawValue: raw)
            }
            let styledBlock = block == .heading || block == .quote
            guard highlighted || underline || styledBlock else { continue }
            edits.append(
                Edit(
                    range: run.range,
                    highlighted: highlighted,
                    underline: underline,
                    block: block,
                    intent: run.inlinePresentationIntent ?? []
                )
            )
        }

        for edit in edits {
            if edit.highlighted {
                result[edit.range].backgroundColor = Theme.Palette.highlightMint
            }
            if edit.underline {
                result[edit.range][AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = Text.LineStyle.single
            }
            if edit.block == .heading {
                result[edit.range][AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.selahCardTitle
            }
            if edit.block == .quote {
                var intent = edit.intent
                intent.insert(.emphasized)
                result[edit.range].inlinePresentationIntent = intent
                if !edit.highlighted {
                    result[edit.range][AttributeScopes.SwiftUIAttributes.ForegroundColorAttribute.self] = Color.secondary
                }
            }
        }
        return result
    }
}

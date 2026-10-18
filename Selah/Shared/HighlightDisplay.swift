import SwiftUI

extension AttributedString {
    /// For read-only display (for example `Text(entry.note.highlightedForDisplay())`).
    /// Adds the soft mint background to every highlighted run. The background is never stored with the note:
    /// it is always derived from the highlight ID, so the stored text stays small and safe to decode.
    func highlightedForDisplay() -> AttributedString {
        var result = self
        let ranges = result.runs.compactMap { run -> Range<AttributedString.Index>? in
            run[HighlightIDAttribute.self] == nil ? nil : run.range
        }
        for range in ranges {
            result[range].backgroundColor = Theme.Palette.highlightMint
        }
        return result
    }
}

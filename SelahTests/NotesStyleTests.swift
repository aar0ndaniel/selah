import Foundation
import Testing
@testable import Selah

struct NotesStyleTests {
    private func item(_ id: String, daysAgo: Int, pinned: Bool) -> NoteItem {
        NoteItem(
            id: id, kind: .personal, title: id, snippet: "",
            date: Date(timeIntervalSince1970: 1_800_000_000 - Double(daysAgo) * 86_400),
            colour: .sage, pinned: pinned, verseRefs: []
        )
    }

    @Test func bookToneIsStableAndNeverSky() {
        for name in ["Philippians", "John", "Psalms", "1 Corinthians", "Genesis", ""] {
            #expect(NotesStyle.tone(forBook: name) == NotesStyle.tone(forBook: name))
            #expect(NotesStyle.tone(forBook: name) != .sky)
        }
    }

    @Test func readMinutesRoundsUpAndIsAtLeastOne() {
        #expect(NotesStyle.readMinutes(wordCount: 0) == 1)
        #expect(NotesStyle.readMinutes(wordCount: 200) == 1)
        #expect(NotesStyle.readMinutes(wordCount: 201) == 2)
        #expect(NotesStyle.readMinutes(wordCount: 640) == 4)
    }

    @Test func attributedStringCountsWordsAndHighlights() {
        var text = AttributedString("Hope is an anchor for the soul")
        let range = text.range(of: "anchor")!
        text[range][HighlightIDAttribute.self] = "h1"
        let other = text.range(of: "soul")!
        text[other][HighlightIDAttribute.self] = "h2"
        #expect(text.wordCount == 7)
        #expect(text.highlightCount == 2)
    }

    @Test func sortOrders() {
        let items = [
            item("old", daysAgo: 10, pinned: false),
            item("pinnedOld", daysAgo: 20, pinned: true),
            item("new", daysAgo: 1, pinned: false)
        ]
        #expect(NoteSort.pinnedFirst.apply(items).map { $0.id } == ["pinnedOld", "new", "old"])
        #expect(NoteSort.newest.apply(items).map { $0.id } == ["new", "old", "pinnedOld"])
        #expect(NoteSort.oldest.apply(items).map { $0.id } == ["pinnedOld", "old", "new"])
    }
}

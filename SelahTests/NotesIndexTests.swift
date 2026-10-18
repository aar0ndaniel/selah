import Foundation
import Testing
@testable import Selah

struct NotesIndexTests {
    private func item(
        _ id: String,
        kind: NoteKind = .personal,
        title: String = "",
        snippet: String = "",
        day: Int = 1,
        pinned: Bool = false,
        refs: [String] = []
    ) -> NoteItem {
        NoteItem(
            id: id,
            kind: kind,
            title: title,
            snippet: snippet,
            date: Date(timeIntervalSince1970: TimeInterval(day) * 86_400),
            colour: .mint,
            pinned: pinned,
            verseRefs: refs
        )
    }

    private var sample: [NoteItem] {
        [
            item("a", kind: .study, title: "Philippians 4 \u{00B7} 3 Mar", snippet: "Do not be anxious", day: 3,
                 refs: ["Philippians 4", "Philippians 4:6-7"]),
            item("b", kind: .service, title: "Grace that saves", snippet: "Ephesians sermon notes", day: 5,
                 refs: ["Ephesians 2:8"]),
            item("c", kind: .personal, title: "Caf\u{00E9} prayer list", snippet: "Pray for the team", day: 2, pinned: true),
            item("d", kind: .study, title: "Philippians 2 \u{00B7} 1 Mar", snippet: "Humility of Christ", day: 1,
                 refs: ["Philippians 2", "Philippians 2:5"])
        ]
    }

    private func ids(_ items: [NoteItem]) -> [String] { items.map { $0.id } }

    @Test func emptyQueryReturnsAll() {
        #expect(NotesIndex.filter(sample, kind: nil, query: "").count == 4)
        #expect(NotesIndex.filter(sample, kind: nil, query: "   ").count == 4)
    }

    @Test func matchesTitle() {
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "grace")) == ["b"])
    }

    @Test func matchesSnippet() {
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "pray for")) == ["c"])
    }

    @Test func isCaseAndDiacriticInsensitive() {
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "CAFE")) == ["c"])
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "humility")) == ["d"])
    }

    @Test func matchesShortVerseReference() {
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "Phil 4")) == ["a"])
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "phil 2")) == ["d"])
    }

    @Test func matchesFullVerseReference() {
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "Philippians 4:6")) == ["a"])
        // A whole-chapter study note covers every verse in that chapter.
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "Philippians 4:9")) == ["a"])
        #expect(NotesIndex.filter(sample, kind: nil, query: "Philippians 3:1").isEmpty)
        #expect(ids(NotesIndex.filter(sample, kind: nil, query: "Eph 2:8")) == ["b"])
    }

    @Test func kindFilter() {
        #expect(Set(ids(NotesIndex.filter(sample, kind: .study, query: ""))) == ["a", "d"])
        #expect(ids(NotesIndex.filter(sample, kind: .service, query: "")) == ["b"])
        #expect(ids(NotesIndex.filter(sample, kind: .personal, query: "")) == ["c"])
    }

    @Test func kindAndQueryTogether() {
        #expect(ids(NotesIndex.filter(sample, kind: .service, query: "phil")).isEmpty)
        #expect(ids(NotesIndex.filter(sample, kind: .study, query: "phil 4")) == ["a"])
    }

    @Test func noMatchesReturnsEmpty() {
        #expect(NotesIndex.filter(sample, kind: nil, query: "zzz").isEmpty)
    }

    @Test func pinnedFirstThenNewestFirst() {
        let sections = NotesIndex.sections(sample)
        #expect(ids(sections.pinned) == ["c"])
        #expect(ids(sections.others) == ["b", "a", "d"])
    }
}

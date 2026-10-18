import Foundation
import Testing
@testable import Selah

struct ReferenceParserTests {
    private let parser = ReferenceParser()

    private func check(_ text: String, _ book: String, _ chapter: Int, _ start: Int?, _ end: Int?) {
        let ref = parser.parse(text)
        #expect(ref?.bookName == book, "book for \(text)")
        #expect(ref?.chapter == chapter, "chapter for \(text)")
        #expect(ref?.verseStart == start, "start for \(text)")
        #expect(ref?.verseEnd == end, "end for \(text)")
    }

    @Test func singleVerse() {
        check("John 3:16", "John", 3, 16, nil)
        check("Jn 3:16", "John", 3, 16, nil)
        check("john 3:16", "John", 3, 16, nil)
        check("JOHN 3:16", "John", 3, 16, nil)
    }

    @Test func numberedBooks() {
        check("1 John 1:9", "1 John", 1, 9, nil)
        check("1Jn 1:9", "1 John", 1, 9, nil)
        check("1 Jn 1:9", "1 John", 1, 9, nil)
        check("I John 1:9", "1 John", 1, 9, nil)
        check("First John 1:9", "1 John", 1, 9, nil)
        check("2 Tim 3:16", "2 Timothy", 3, 16, nil)
        check("1 Cor 13:4-7", "1 Corinthians", 13, 4, 7)
    }

    @Test func wholeChapter() {
        check("Psalm 23", "Psalms", 23, nil, nil)
        check("Ps 23", "Psalms", 23, nil, nil)
        check("Genesis 1", "Genesis", 1, nil, nil)
    }

    @Test func ranges() {
        check("Phil 4:6-7", "Philippians", 4, 6, 7)
        check("Phil 4:6\u{2013}7", "Philippians", 4, 6, 7)
        check("Phil 4:6\u{2014}7", "Philippians", 4, 6, 7)
        check("Phil 4:6 - 7", "Philippians", 4, 6, 7)
    }

    @Test func messyInput() {
        check("  John   3:16  ", "John", 3, 16, nil)
        check("John 3:16.", "John", 3, 16, nil)
        check("Gen. 1:1", "Genesis", 1, 1, nil)
        check("john 3 16", "John", 3, 16, nil)
    }

    @Test func abbreviations() {
        check("Gen 1:1", "Genesis", 1, 1, nil)
        check("Ex 20:3", "Exodus", 20, 3, nil)
        check("Song 2:1", "Song of Solomon", 2, 1, nil)
        check("Song of Songs 2:1", "Song of Solomon", 2, 1, nil)
        check("Rev 21:4", "Revelation", 21, 4, nil)
        check("Revelations 21:4", "Revelation", 21, 4, nil)
        check("Mt 5:3", "Matthew", 5, 3, nil)
        check("Mk 1:1", "Mark", 1, 1, nil)
        check("Lk 2:10", "Luke", 2, 10, nil)
        check("Jas 1:5", "James", 1, 5, nil)
        check("Phlm 6", "Philemon", 1, 6, nil)
        check("Isa 40:31", "Isaiah", 40, 31, nil)
        check("Jer 29:11", "Jeremiah", 29, 11, nil)
    }

    @Test func singleChapterBooks() {
        check("Jude 3", "Jude", 1, 3, nil)
        check("Jude 1:3", "Jude", 1, 3, nil)
        check("Jude 3-5", "Jude", 1, 3, 5)
        check("Obadiah 15", "Obadiah", 1, 15, nil)
        check("2 John 6", "2 John", 1, 6, nil)
        check("3 John 4", "3 John", 1, 4, nil)
        check("Philemon 10", "Philemon", 1, 10, nil)
    }

    @Test func allBooksParseByName() {
        for (index, name) in BibleBooks.names.enumerated() {
            let ref = parser.parse("\(name) 1")
            #expect(ref?.bookID == index + 1, "\(name)")
        }
    }

    @Test func invalidInputIsNil() {
        #expect(parser.parse("") == nil)
        #expect(parser.parse("   ") == nil)
        #expect(parser.parse("hello world") == nil)
        #expect(parser.parse("John") == nil)
        #expect(parser.parse("3:16") == nil)
        #expect(parser.parse("John 0:1") == nil)
        #expect(parser.parse("John 3:0") == nil)
        #expect(parser.parse("Phil 4:7-6") == nil)
        #expect(parser.parse("Foo 3:16") == nil)
    }

    @Test func chapterOutOfRangeIsNil() {
        #expect(parser.parse("John 22") == nil)
        #expect(parser.parse("John 22:1") == nil)
        #expect(parser.parse("Psalm 151") == nil)
        #expect(parser.parse("Jude 2:1") == nil)
        #expect(parser.parse("Psalm 150") != nil)
    }

    @Test func suggestionsWhileTyping() {
        #expect(parser.suggestions(for: "1 j") == ["1 John"])
        #expect(parser.suggestions(for: "Phil") == ["Philippians", "Philemon"])
        #expect(parser.suggestions(for: "gen") == ["Genesis"])
        #expect(parser.suggestions(for: "") == [])
        #expect(parser.suggestions(for: "zzz") == [])
        #expect(parser.suggestions(for: "jo").contains("John"))
        #expect(parser.suggestions(for: "jo").contains("Joshua"))
        #expect(parser.suggestions(for: "song").contains("Song of Solomon"))
    }

    @Test func displayStrings() {
        #expect(parser.parse("Phil 4:6-7")?.displayString == "Philippians 4:6-7")
        #expect(parser.parse("Psalm 23")?.displayString == "Psalms 23")
        #expect(parser.parse("Jn 3:16")?.displayString == "John 3:16")
    }

    @Test func popularPassagesAllParse() {
        #expect(PopularPassages.all.count == 12)
    }
}

struct BibleStoreTests {
    @Test(.enabled(if: BibleStore.shared.isAvailable))
    func philippiansKJV() {
        let ref = ReferenceParser().parse("Phil 4:6-7")
        #expect(ref != nil)
        guard let ref else { return }
        let text = BibleStore.shared.text(for: ref, translation: .kjv)
        #expect(text.contains("Be careful for nothing"))
    }

    @Test(.enabled(if: BibleStore.shared.isAvailable))
    func firstJohnKJV() {
        let ref = ReferenceParser().parse("1 John 1:9")
        #expect(ref != nil)
        guard let ref else { return }
        let text = BibleStore.shared.text(for: ref, translation: .kjv)
        #expect(text.contains("faithful and just"))
    }
}

import Foundation
import Testing
@testable import Selah

// Pure parsing only: the network calls in HymnaryClient are not unit tested.

struct HymnaryCSVTests {
    @Test func plainRowsAndEmptyFields() {
        let rows = HymnaryParsing.parseCSV("a,b,c\n1,,3\n,,\n")
        #expect(rows == [["a", "b", "c"], ["1", "", "3"], ["", "", ""]])
    }

    @Test func quotedFieldsKeepCommasQuotesAndLineBreaks() {
        let csv = "title,authors\n\"Holy, holy, holy\",\"Reginald Heber, 1826\"\n\"He said \"\"Peace\"\"\",\"line one\nline two\"\n"
        let rows = HymnaryParsing.parseCSV(csv)
        #expect(rows.count == 3)
        #expect(rows[1] == ["Holy, holy, holy", "Reginald Heber, 1826"])
        #expect(rows[2] == ["He said \"Peace\"", "line one\nline two"])
    }

    @Test func crlfRowEndsBlankLinesBomAndNoTrailingNewline() {
        let csv = "\u{FEFF}a,b\r\n\r\n1,2\r\n3,4"
        #expect(HymnaryParsing.parseCSV(csv) == [["a", "b"], ["1", "2"], ["3", "4"]])
    }

    @Test func emptyTextHasNoRows() {
        #expect(HymnaryParsing.parseCSV("").isEmpty)
        #expect(HymnaryParsing.parseCSV("\n\n").isEmpty)
    }

    @Test func emptyQuotedFieldIsEmptyString() {
        #expect(HymnaryParsing.parseCSV("a,\"\",c\n") == [["a", "", "c"]])
    }
}

struct HymnarySearchParsingTests {
    private let header = "displayTitle,firstLine,textTitle,refrainFirstLine,textAuthNumber,languages,authors,meter,textSources,totalInstances"

    @Test func readsColumnsByHeaderNameAndSortsByInstances() {
        let csv = """
        \(header)
        "Amazing Grace!","Amazing grace! how sweet the sound","Amazing Grace",,"amazing_grace_how_sweet_the_sound",English,"John Newton, 1725-1807",86.86,,1120
        "Amazing Grace (Chinese)","Amazing grace","Amazing Grace",,"amazing_grace_zh",Chinese,"Unknown",,,12
        "Grace, Amazing","Grace amazing","Grace Amazing","Refrain here","grace_amazing",English,"A, B",,,300
        """
        let results = HymnaryParsing.parseSearchResults(csv: csv)
        #expect(results.map { $0.textAuthNumber } == ["amazing_grace_how_sweet_the_sound", "grace_amazing", "amazing_grace_zh"])
        #expect(results[0].displayTitle == "Amazing Grace!")
        #expect(results[0].authors == "John Newton, 1725-1807")
        #expect(results[0].meter == "86.86")
        #expect(results[0].totalInstances == 1120)
        #expect(results[1].refrainFirstLine == "Refrain here")
        #expect(results[1].authors == "A, B")
    }

    @Test func keepsOnlyTheTopEightAndDropsRowsWithoutAnId() {
        var lines = [header]
        for number in 1...12 {
            lines.append("T\(number),First \(number),T\(number),,id\(number),,Author,,,\(number)")
        }
        lines.append("No id,First,No id,,,,,,,9999")
        let results = HymnaryParsing.parseSearchResults(csv: lines.joined(separator: "\n"))
        #expect(results.count == 8)
        #expect(results.first?.textAuthNumber == "id12")
        #expect(results.last?.textAuthNumber == "id5")
        #expect(!results.contains { $0.displayTitle == "No id" })
    }

    @Test func mergesRepeatsAndKeepsHymnaryOrderForEqualCounts() {
        let csv = """
        \(header)
        "B","","B",,"id_b",,,,,5
        "A","","A",,"id_a",,,,,5
        "A again","","A",,"id_a",,,,,5
        """
        let results = HymnaryParsing.parseSearchResults(csv: csv)
        #expect(results.map { $0.textAuthNumber } == ["id_b", "id_a"])
    }

    @Test func missingHeaderColumnOrEmptyReplyGivesNothing() {
        #expect(HymnaryParsing.parseSearchResults(csv: "").isEmpty)
        #expect(HymnaryParsing.parseSearchResults(csv: "a,b\n1,2\n").isEmpty)
        #expect(HymnaryParsing.parseSearchResults(csv: "<html>Not found</html>").isEmpty)
    }

    @Test func suggestionTitleAndDetailLine() {
        let result = HymnarySearchResult(
            displayTitle: " ",
            firstLine: "Amazing grace! how sweet the sound",
            textTitle: "Amazing Grace",
            textAuthNumber: "x",
            authors: "John Newton"
        )
        #expect(result.suggestedTitle == "Amazing Grace")
        #expect(result.detailLine == "Amazing grace! how sweet the sound \u{00B7} John Newton")

        // The first line is not repeated when it is the title.
        let same = HymnarySearchResult(displayTitle: "Holy holy holy", firstLine: "holy holy holy", textAuthNumber: "y", authors: "Heber")
        #expect(same.detailLine == "Heber")
    }

    @Test func urlsAreEncodedLikeTheTestedEndpoints() {
        #expect(HymnaryParsing.searchURL(title: "Amazing grace")?.absoluteString
            == "https://hymnary.org/search?qu=Amazing%20grace%20in:texts&export=csv")
        #expect(HymnaryParsing.searchURL(title: "Holy, holy & more")?.absoluteString
            == "https://hymnary.org/search?qu=Holy%2C%20holy%20%26%20more%20in:texts&export=csv")
        #expect(HymnaryParsing.searchURL(title: "  ") == nil)
        #expect(HymnaryParsing.fulltextURL(textAuthNumber: "amazing_grace")?.absoluteString
            == "https://hymnary.org/api/fulltext/amazing_grace")
        #expect(HymnaryParsing.fulltextURL(textAuthNumber: "") == nil)
    }
}

struct HymnaryFulltextTests {
    private let json = #"""
    [
      {"title":"Hymnal A","hymnalID":"ABC","number":"12","text":"Copyrighted words\nnot for display","displayPermissions":"none","date":"1990","classifications":"x"},
      {"title":"Hymnal B","hymnalID":55,"number":7,"text":"Unnumbered line\n\nsecond block","displayPermissions":"all","date":1900},
      {"title":"Hymnal C","hymnalID":"C","number":"3","text":"1. First\n\r\nline\n\r\n\n2. Second","displayPermissions":"all","date":"1880","classifications":["a","b"]}
    ]
    """#

    @Test func decodesLooselyTypedFields() throws {
        let entries = try HymnaryParsing.decodeFulltext(Data(json.utf8))
        #expect(entries.count == 3)
        #expect(entries[1].hymnalID == "55")
        #expect(entries[1].number == "7")
        #expect(entries[1].date == "1900")
        #expect(entries[2].classifications == "a, b")
        #expect(entries[0].displayPermissions == "none")
    }

    @Test func emptyArrayAndBadJSON() throws {
        #expect(try HymnaryParsing.decodeFulltext(Data("[]".utf8)).isEmpty)
        #expect(throws: HymnaryError.unreadable) {
            try HymnaryParsing.decodeFulltext(Data("{\"error\":\"nope\"}".utf8))
        }
        #expect(throws: HymnaryError.unreadable) {
            try HymnaryParsing.decodeFulltext(Data("not json".utf8))
        }
    }

    @Test func onlyDisplayableEntriesAreUsedAndNumberedVersesWin() throws {
        let entries = try HymnaryParsing.decodeFulltext(Data(json.utf8))
        let chosen = try #require(HymnaryParsing.displayableEntry(in: entries))
        #expect(chosen.title == "Hymnal C")

        let lyrics = try #require(HymnaryParsing.lyrics(from: entries))
        #expect(lyrics.verses == ["First\nline", "Second"])
        #expect(lyrics.refrain == nil)
        #expect(lyrics.sourceHymnal == "Hymnal C")
        #expect(lyrics.number == "3")
    }

    @Test func fallsBackToTheFirstDisplayableEntryWithoutNumbers() {
        let entries = [
            HymnaryFulltextEntry(title: "A", text: "x", displayPermissions: "restricted"),
            HymnaryFulltextEntry(title: "B", text: "Line one\nline two\n\nLine three", displayPermissions: "ALL"),
            HymnaryFulltextEntry(title: "C", text: "Other", displayPermissions: "all")
        ]
        #expect(HymnaryParsing.displayableEntry(in: entries)?.title == "B")
        #expect(HymnaryParsing.lyrics(from: entries)?.verses == ["Line one\nline two", "Line three"])
    }

    @Test func noPermissionMeansNoLyrics() {
        let entries = [
            HymnaryFulltextEntry(title: "A", text: "1. Words", displayPermissions: "none"),
            HymnaryFulltextEntry(title: "B", text: "1. Words", displayPermissions: ""),
            HymnaryFulltextEntry(title: "C", text: "1. Words", displayPermissions: "some"),
            HymnaryFulltextEntry(title: "D", text: "   ", displayPermissions: "all")
        ]
        #expect(HymnaryParsing.displayableEntry(in: entries) == nil)
        #expect(HymnaryParsing.lyrics(from: entries) == nil)
        #expect(HymnaryParsing.lyrics(from: []) == nil)
    }
}

struct HymnaryLyricsParsingTests {
    /// The shape of the real Amazing Grace reply: "\n\r\n" between lines, "\n\r\n\n" between verses.
    private let amazingGrace = "1. Amazing grace! how sweet the sound\n\r\nThat saved a wretch like me!\n\r\nI once was lost, but now am found,\n\r\nWas blind, but now I see.\n\r\n\n2. 'Twas grace that taught my heart to fear,\n\r\nAnd grace my fears relieved;\n\r\nHow precious did that grace appear\n\r\nThe hour I first believed!"

    @Test func lineBreaksAreNormalised() {
        #expect(HymnaryParsing.normaliseLineBreaks("a\n\r\nb") == "a\nb")
        #expect(HymnaryParsing.normaliseLineBreaks("a\r\nb") == "a\nb")
        #expect(HymnaryParsing.normaliseLineBreaks("a\rb") == "a\nb")
        #expect(HymnaryParsing.normaliseLineBreaks("a\n\r\n\nb") == "a\n\nb")
        #expect(HymnaryParsing.normaliseLineBreaks("a\r\n\r\nb") == "a\n\nb")
    }

    @Test func numberedVersesLoseTheirNumbers() {
        let parsed = HymnaryParsing.parseLyrics(amazingGrace)
        #expect(parsed.verses == [
            "Amazing grace! how sweet the sound\nThat saved a wretch like me!\nI once was lost, but now am found,\nWas blind, but now I see.",
            "'Twas grace that taught my heart to fear,\nAnd grace my fears relieved;\nHow precious did that grace appear\nThe hour I first believed!"
        ])
        #expect(parsed.refrain == nil)
        #expect(HymnaryParsing.hasNumberedVerses(amazingGrace))
    }

    @Test func numberedLineRules() {
        #expect(HymnaryParsing.numberedLine("1. Amazing grace")?.number == 1)
        #expect(HymnaryParsing.numberedLine("1. Amazing grace")?.rest == "Amazing grace")
        #expect(HymnaryParsing.numberedLine("  12) Words")?.rest == "Words")
        #expect(HymnaryParsing.numberedLine("2.")?.rest == "")
        #expect(HymnaryParsing.numberedLine("1.Amazing")?.rest == "Amazing")
        #expect(HymnaryParsing.numberedLine("1.5 million") == nil)
        #expect(HymnaryParsing.numberedLine("Amazing") == nil)
        #expect(HymnaryParsing.numberedLine("1 Amazing") == nil)
    }

    @Test func unnumberedBlocksAreVerses() {
        let parsed = HymnaryParsing.parseLyrics("Line one\nline two\n\nLine three\nline four")
        #expect(parsed.verses == ["Line one\nline two", "Line three\nline four"])
        #expect(parsed.refrain == nil)
    }

    @Test func labelledRefrainBlock() {
        let text = "1. Verse one a\nverse one b\n\nRefrain:\nGlory, glory\nHallelujah\n\n2. Verse two a\nverse two b"
        let parsed = HymnaryParsing.parseLyrics(text)
        #expect(parsed.verses == ["Verse one a\nverse one b", "Verse two a\nverse two b"])
        #expect(parsed.refrain == "Glory, glory\nHallelujah")
    }

    @Test func refrainLabelInsideAVerseBlockSplitsIt() {
        let parsed = HymnaryParsing.parseLyrics("1. Line a\nLine b\nChorus: Sing it\nAgain\n\n2. Line c")
        #expect(parsed.verses == ["Line a\nLine b", "Line c"])
        #expect(parsed.refrain == "Sing it\nAgain")
    }

    @Test func unlabelledBlockBetweenNumberedVersesIsTheRefrain() {
        let text = "1. Blessed assurance, Jesus is mine!\nO what a foretaste of glory divine!\n\nThis is my story, this is my song,\nPraising my Saviour all the day long.\n\n2. Perfect submission, perfect delight,\nVisions of rapture now burst on my sight;\n\nThis is my story, this is my song,\nPraising my Saviour all the day long."
        let parsed = HymnaryParsing.parseLyrics(text)
        #expect(parsed.verses.count == 2)
        #expect(parsed.verses[1].hasPrefix("Perfect submission"))
        #expect(parsed.refrain == "This is my story, this is my song,\nPraising my Saviour all the day long.")
    }

    @Test func repeatedBlockWithoutNumbersIsTheRefrain() {
        let text = "Verse A line\nmore A\n\nChorus text\nmore chorus\n\nVerse B line\nmore B\n\nChorus text\nmore chorus"
        let parsed = HymnaryParsing.parseLyrics(text)
        #expect(parsed.verses == ["Verse A line\nmore A", "Verse B line\nmore B"])
        #expect(parsed.refrain == "Chorus text\nmore chorus")
    }

    @Test func wordsStartingWithChorusAreNotLabels() {
        #expect(HymnaryParsing.refrainLabel("Chorus of angels sing") == nil)
        #expect(HymnaryParsing.refrainLabel("Refrain") == "")
        #expect(HymnaryParsing.refrainLabel("refrain:") == "")
        #expect(HymnaryParsing.refrainLabel("Chorus: Glory") == "Glory")
        #expect(HymnaryParsing.refrainLabel("(Refrain)") == "")
    }

    @Test func emptyTextHasNothing() {
        let parsed = HymnaryParsing.parseLyrics(" \n\r\n\n ")
        #expect(parsed.verses.isEmpty)
        #expect(parsed.refrain == nil)
    }
}

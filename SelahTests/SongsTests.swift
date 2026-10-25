import Foundation
import SwiftData
import Testing
@testable import Selah

struct SongsOrderTests {
    private func titles(_ entries: [SongsEntry], _ order: [Int]) -> [String] {
        order.map { entries[$0].title }
    }

    @Test func alphabeticalIgnoresCaseAccentsAndPunctuationAndPutsDigitsLast() {
        let entries = [
            SongsEntry(title: "banana"),
            SongsEntry(title: "Apple"),
            SongsEntry(title: "\u{00C9}cole du dimanche"),
            SongsEntry(title: "cherry"),
            SongsEntry(title: "10,000 reasons"),
            SongsEntry(title: "'Twas grace")
        ]
        let order = SongsLogic.order(entries, sort: .alphabetical)
        #expect(titles(entries, order) == [
            "Apple", "banana", "cherry", "\u{00C9}cole du dimanche", "'Twas grace", "10,000 reasons"
        ])
    }

    @Test func alphabeticalTiesKeepTheirOriginalOrder() {
        let entries = [
            SongsEntry(title: "Holy", type: .chorus),
            SongsEntry(title: "holy!", type: .hymn),
            SongsEntry(title: "Holy", type: .worship)
        ]
        #expect(SongsLogic.order(entries, sort: .alphabetical) == [0, 1, 2])
    }

    @Test func recentlyLoggedPutsTheLatestServiceFirstThenNewestAdded() {
        let entries = [
            SongsEntry(title: "Never sung, old", createdAt: Date(timeIntervalSince1970: 100)),
            SongsEntry(title: "Sung long ago", lastSungAt: Date(timeIntervalSince1970: 1_000), createdAt: Date(timeIntervalSince1970: 50)),
            SongsEntry(title: "Sung last week", lastSungAt: Date(timeIntervalSince1970: 9_000), createdAt: Date(timeIntervalSince1970: 60)),
            SongsEntry(title: "Never sung, new", createdAt: Date(timeIntervalSince1970: 500)),
            SongsEntry(title: "Sung same day", lastSungAt: Date(timeIntervalSince1970: 9_000), createdAt: Date(timeIntervalSince1970: 70))
        ]
        let order = SongsLogic.order(entries, sort: .recentlyLogged)
        // Same service date: the one added later first. Then songs that were never sung, newest added first.
        #expect(titles(entries, order) == [
            "Sung same day", "Sung last week", "Sung long ago", "Never sung, new", "Never sung, old"
        ])
    }

    @Test func mostSungGoesByCountThenAToZ() {
        let entries = [
            SongsEntry(title: "Beta", timesSung: 2),
            SongsEntry(title: "Alpha", timesSung: 2),
            SongsEntry(title: "Zeta", timesSung: 5),
            SongsEntry(title: "Omega", timesSung: 0)
        ]
        let order = SongsLogic.order(entries, sort: .mostSung)
        #expect(titles(entries, order) == ["Zeta", "Alpha", "Beta", "Omega"])
    }

    @Test func filterKeepsOneTypeAndAllKeepsEverything() {
        let entries = [
            SongsEntry(title: "A hymn", type: .hymn),
            SongsEntry(title: "A chorus", type: .chorus),
            SongsEntry(title: "A worship song", type: .worship)
        ]
        #expect(titles(entries, SongsLogic.order(entries, sort: .alphabetical, filter: .hymns)) == ["A hymn"])
        #expect(titles(entries, SongsLogic.order(entries, sort: .alphabetical, filter: .choruses)) == ["A chorus"])
        #expect(titles(entries, SongsLogic.order(entries, sort: .alphabetical, filter: .worship)) == ["A worship song"])
        #expect(SongsLogic.order(entries, sort: .alphabetical, filter: .all).count == 3)
    }

    @Test func searchLooksInTitleNumberAndLyrics() {
        let entries = [
            SongsEntry(title: "Blessed assurance", type: .hymn, hymnNumber: "245", lyricsText: "Jesus is mine\nforetaste of glory"),
            SongsEntry(title: "This is the day", type: .chorus, hymnNumber: "245", lyricsText: ""),
            SongsEntry(title: "Cr\u{00E8}me de la cr\u{00E8}me", type: .worship)
        ]
        // Title, any case.
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "ASSURANCE") == [0])
        // Hymn number counts for hymns only.
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "245") == [0])
        // Lyrics.
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "foretaste glory") == [0])
        // Accents are ignored.
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "creme") == [2])
        // Blank query shows everything; no match shows nothing.
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "  ").count == 3)
        #expect(SongsLogic.order(entries, sort: .alphabetical, query: "zzz").isEmpty)
    }

    @Test func filterAndSearchWorkTogether() {
        let entries = [
            SongsEntry(title: "Holy, holy, holy", type: .hymn),
            SongsEntry(title: "Holy forever", type: .worship)
        ]
        #expect(SongsLogic.order(entries, sort: .alphabetical, filter: .worship, query: "holy") == [1])
    }
}

struct SongsSectionTests {
    @Test func sectionLettersFoldAccentsAndUseHashForDigitsAndSymbols() {
        #expect(SongsLogic.sectionLetter(for: "Amazing grace") == "A")
        #expect(SongsLogic.sectionLetter(for: "\u{00C9}cole") == "E")
        #expect(SongsLogic.sectionLetter(for: "'Twas grace") == "T")
        #expect(SongsLogic.sectionLetter(for: "10,000 reasons") == "#")
        #expect(SongsLogic.sectionLetter(for: "") == "#")
        #expect(SongsLogic.sectionLetter(for: "  ...  ") == "#")
    }

    @Test func sectionsGroupAlphabeticalIndicesAndPutHashLast() {
        let entries = [
            SongsEntry(title: "Zion"),
            SongsEntry(title: "Amazing grace"),
            SongsEntry(title: "10,000 reasons"),
            SongsEntry(title: "Alpha and Omega"),
            SongsEntry(title: "Blessed assurance")
        ]
        let order = SongsLogic.order(entries, sort: .alphabetical)
        let sections = SongsLogic.sections(entries, ordered: order)
        #expect(sections.map { $0.letter } == ["A", "B", "Z", "#"])
        #expect(sections[0].indices == [3, 1])
        #expect(sections[1].indices == [4])
        #expect(sections[2].indices == [0])
        #expect(sections[3].indices == [2])
    }

    @Test func noSongsNoSections() {
        #expect(SongsLogic.sections([], ordered: []).isEmpty)
    }
}

struct SongsDeleteGuardTests {
    @Test func unusedSongsMayBeDeleted() {
        #expect(SongsLogic.deleteDecision(serviceCount: 0) == .allowed)
    }

    @Test func songsInServicesAreBlockedWithTheCountInTheTitle() {
        #expect(SongsLogic.deleteDecision(serviceCount: 1)
            == .blocked(title: "This song is in 1 service", message: "Take it out of that service first, then delete it here."))
        #expect(SongsLogic.deleteDecision(serviceCount: 3)
            == .blocked(title: "This song is in 3 services", message: "Take it out of those services first, then delete it here."))
    }

    @MainActor
    @Test func theLibraryRefusesToDeleteASongUsedInServices() throws {
        let schema = Schema(SampleData.allModels)
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let used = LibrarySong(title: "Used", source: .added)
        let unused = LibrarySong(title: "Unused", source: .added)
        context.insert(used)
        context.insert(unused)
        var firstService: Service?
        for day in 1...2 {
            let service = Service(date: Date(timeIntervalSince1970: Double(day) * 86_400), gatheringName: "Sunday")
            service.partsMigrated = true
            context.insert(service)
            if firstService == nil { firstService = service }
            let part = ServicePart(kind: .song, title: "Used")
            context.insert(part)
            part.service = service
            part.librarySong = used
        }
        // A second part in the same service still counts as one service.
        let again = ServicePart(kind: .song, title: "Used")
        context.insert(again)
        again.service = firstService
        again.librarySong = used
        try context.save()

        #expect(SongLibrary.serviceCount(of: used) == 2)
        let refused = SongLibrary.deleteIfUnused(used, in: context)
        #expect(refused == .blocked(title: "This song is in 2 services", message: "Take it out of those services first, then delete it here."))
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 2)

        #expect(SongLibrary.deleteIfUnused(unused, in: context) == .allowed)
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 1)
    }

    @MainActor
    @Test func importedLyricsNeverReplaceTypedOnes() throws {
        let lyrics = SongsHymnLyrics(verses: ["One", "Two"], refrain: "Sing", sourceHymnal: "H", number: "1")

        let empty = LibrarySong(title: "Empty", source: .logged)
        #expect(SongLibrary.applyImport(lyrics, externalID: "id_empty", to: empty))
        #expect(empty.lyricVerses == ["One", "Two"])
        #expect(empty.refrain == "Sing")
        #expect(empty.externalID == "id_empty")
        #expect(empty.source == .imported)
        #expect(empty.lyricsCredit == "Lyrics from Hymnary.org")

        let typed = LibrarySong(title: "Typed", lyricVerses: ["My words"], source: .added)
        #expect(!SongLibrary.applyImport(lyrics, externalID: "id_typed", to: typed))
        #expect(typed.lyricVerses == ["My words"])
        #expect(typed.source == .added)
        #expect(typed.lyricsCredit == nil)
    }
}

struct SongsTextTests {
    @Test func creditLineOnlyForImportedLyrics() {
        #expect(SongsLogic.creditLine(source: .imported, externalID: "x", hasLyrics: true) == "Lyrics from Hymnary.org")
        #expect(SongsLogic.creditLine(source: .imported, externalID: "x", hasLyrics: false) == nil)
        #expect(SongsLogic.creditLine(source: .imported, externalID: nil, hasLyrics: true) == nil)
        #expect(SongsLogic.creditLine(source: .added, externalID: "x", hasLyrics: true) == nil)
        #expect(SongsLogic.creditLine(source: .logged, externalID: nil, hasLyrics: true) == nil)
    }

    @Test func firstLineComesFromTheFirstVerseOrTheRefrain() {
        #expect(SongsLogic.firstLine(verses: ["\n Blessed assurance\nJesus is mine"], refrain: "Chorus") == "Blessed assurance")
        #expect(SongsLogic.firstLine(verses: ["  ", ""], refrain: "This is my story") == "This is my story")
        #expect(SongsLogic.firstLine(verses: [], refrain: " ") == nil)
    }

    @Test func cleanedVersesTrimAndDropEmptyOnes() {
        #expect(SongsLogic.cleanedVerses([" One \n", "", "  ", "Two"]) == ["One", "Two"])
    }

    @Test func rowAccessibilityLabelReadsTheWholeCard() {
        #expect(SongsLogic.rowAccessibilityLabel(title: "Blessed assurance", type: .hymn, hymnNumber: "245", timesSung: 3, hasLyrics: true)
            == "Hymn 245, Blessed assurance, sung 3 times, has lyrics")
        #expect(SongsLogic.rowAccessibilityLabel(title: "This is the day", type: .chorus, hymnNumber: "", timesSung: 1, hasLyrics: false)
            == "This is the day, Chorus, sung once")
    }

    @Test func sortAndFilterTitles() {
        #expect(SongsSort.alphabetical.title == "A\u{2013}Z")
        #expect(SongsSort.recentlyLogged.title == "Recently logged")
        #expect(SongsSort.mostSung.title == "Most sung")
        #expect(SongsFilter.allCases.map { $0.chipTitle } == ["All", "Hymns", "Choruses", "Worship"])
    }
}

struct LyricsPracticeLogicTests {
    @Test func eachVerseGetsTheRefrainAfterIt() {
        let blocks = LyricsPracticeLogic.blocks(verses: ["One", " ", "Two"], refrain: " Sing \n")
        #expect(blocks == [
            LyricsPracticeBlock(verseNumber: 1, text: "One", refrain: "Sing"),
            LyricsPracticeBlock(verseNumber: 2, text: "Two", refrain: "Sing")
        ])
    }

    @Test func noRefrainMeansNoRefrainBlock() {
        let blocks = LyricsPracticeLogic.blocks(verses: ["One"], refrain: "")
        #expect(blocks == [LyricsPracticeBlock(verseNumber: 1, text: "One", refrain: nil)])
    }

    @Test func aRefrainOnlySongIsOneBlockAndNothingIsNothing() {
        #expect(LyricsPracticeLogic.blocks(verses: [], refrain: "Only this")
            == [LyricsPracticeBlock(verseNumber: nil, text: "Only this", refrain: nil)])
        #expect(LyricsPracticeLogic.blocks(verses: [" "], refrain: " ").isEmpty)
    }

    @Test func chipTextAndMoving() {
        let blocks = LyricsPracticeLogic.blocks(verses: ["a", "b", "c", "d", "e", "f"], refrain: "")
        #expect(LyricsPracticeLogic.chipText(blocks: blocks, index: 1) == "Verse 2 of 6")
        #expect(LyricsPracticeLogic.chipText(blocks: blocks, index: 9) == "")
        let refrainOnly = LyricsPracticeLogic.blocks(verses: [], refrain: "x")
        #expect(LyricsPracticeLogic.chipText(blocks: refrainOnly, index: 0) == "Refrain")

        #expect(LyricsPracticeLogic.moved(from: 0, by: -1, count: 6) == 0)
        #expect(LyricsPracticeLogic.moved(from: 5, by: 1, count: 6) == 5)
        #expect(LyricsPracticeLogic.moved(from: 2, by: 1, count: 6) == 3)
        #expect(LyricsPracticeLogic.moved(from: 0, by: 1, count: 0) == 0)
    }
}

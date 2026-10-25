import Foundation
import SwiftData
import Testing
@testable import Selah

struct SongLibraryLogicTests {
    @Test func normalisedTitleIgnoresCaseAccentsPunctuationAndSpaces() {
        #expect(SongLibraryLogic.normalisedTitle("  Great Is Thy  Faithfulness! ") == "great is thy faithfulness")
        #expect(SongLibraryLogic.normalisedTitle("Holy, holy, holy") == "holy holy holy")
        #expect(SongLibraryLogic.normalisedTitle("Ô Seigneur") == "o seigneur")
        #expect(SongLibraryLogic.normalisedTitle("  ") == "")
    }

    @Test func matchNeedsSameTitleAndType() {
        let library = [
            SongKey(title: "Great is thy faithfulness", type: .hymn, hymnNumber: "12"),
            SongKey(title: "This is the day", type: .chorus)
        ]
        #expect(SongLibraryLogic.matchIndex(for: SongKey(title: "great is THY faithfulness.", type: .hymn), in: library) == 0)
        #expect(SongLibraryLogic.matchIndex(for: SongKey(title: "This is the day", type: .chorus), in: library) == 1)
        // Same title, different type: a different song.
        #expect(SongLibraryLogic.matchIndex(for: SongKey(title: "This is the day", type: .worship), in: library) == nil)
        #expect(SongLibraryLogic.matchIndex(for: SongKey(title: "Unknown", type: .hymn), in: library) == nil)
    }

    @Test func hymnWithOnlyANumberMatchesByNumber() {
        let library = [SongKey(title: "Great is thy faithfulness", type: .hymn, hymnNumber: "12")]
        #expect(SongLibraryLogic.matchIndex(for: SongKey(type: .hymn, hymnNumber: " 12 "), in: library) == 0)
        #expect(SongLibraryLogic.matchIndex(for: SongKey(type: .chorus, hymnNumber: "12"), in: library) == nil)
        #expect(SongLibraryLogic.matchIndex(for: SongKey(type: .hymn, hymnNumber: "13"), in: library) == nil)
        #expect(SongLibraryLogic.matchIndex(for: SongKey(type: .hymn), in: library) == nil)
    }

    @Test func suggestionsPutPrefixAndPreferredTypeFirst() {
        let library = [
            SongKey(title: "How great thou art", type: .hymn, hymnNumber: "17"),
            SongKey(title: "Great is thy faithfulness", type: .hymn, hymnNumber: "12"),
            SongKey(title: "Great are you Lord", type: .worship),
            SongKey(title: "Amazing grace", type: .hymn)
        ]
        let result = SongLibraryLogic.suggestions(for: "great", preferredType: .hymn, in: library)
        // Prefix matches first (hymn before worship), then "contains" matches.
        #expect(result == [1, 2, 0])
        #expect(SongLibraryLogic.suggestions(for: "", in: library).isEmpty)
        #expect(SongLibraryLogic.suggestions(for: "zzz", in: library).isEmpty)
        #expect(SongLibraryLogic.suggestions(for: "great", in: library, limit: 1).count == 1)
    }

    @Test func suggestionsMatchHymnNumbersAndSkipExactTitle() {
        let library = [
            SongKey(title: "Great is thy faithfulness", type: .hymn, hymnNumber: "12"),
            SongKey(title: "Amazing grace", type: .hymn, hymnNumber: "5")
        ]
        #expect(SongLibraryLogic.suggestions(for: "12", in: library) == [0])
        #expect(SongLibraryLogic.suggestions(for: "Amazing grace", preferredType: .hymn, in: library).isEmpty)
    }

    @Test func displayNameShowsNumbersOnlyForHymns() {
        #expect(SongLibraryLogic.displayName(type: .hymn, hymnNumber: "212", title: "Great") == "Hymn 212, Great")
        #expect(SongLibraryLogic.displayName(type: .hymn, hymnNumber: "212", title: " ") == "Hymn 212")
        #expect(SongLibraryLogic.displayName(type: .chorus, hymnNumber: "212", title: "This is the day") == "This is the day")
        #expect(SongLibraryLogic.displayName(type: .worship, hymnNumber: "", title: "") == "")
    }

    @Test func onlyUnusedLoggedSongsWithoutLyricsAreDisposable() {
        #expect(SongLibraryLogic.isDisposable(source: .logged, linkedCount: 0, hasLyrics: false))
        #expect(!SongLibraryLogic.isDisposable(source: .logged, linkedCount: 1, hasLyrics: false))
        #expect(!SongLibraryLogic.isDisposable(source: .logged, linkedCount: 0, hasLyrics: true))
        #expect(!SongLibraryLogic.isDisposable(source: .added, linkedCount: 0, hasLyrics: false))
        #expect(!SongLibraryLogic.isDisposable(source: .imported, linkedCount: 0, hasLyrics: false))
    }
}

@MainActor
struct SongLibraryLinkTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func songPart(_ context: ModelContext, title: String, type: SongType = .hymn, number: String = "", date: Date = Date()) -> ServicePart {
        let service = Service(date: date, gatheringName: "Sunday worship")
        service.partsMigrated = true
        context.insert(service)
        let part = ServicePart(kind: .song, title: title, songType: type, hymnNumber: number)
        context.insert(part)
        part.service = service
        return part
    }

    @Test func linkingCreatesALoggedLibrarySong() throws {
        let context = try makeContext()
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let part = songPart(context, title: " Blessed assurance ", number: "245", date: date)
        let song = try #require(SongLibrary.link(part, in: context))
        try context.save()
        #expect(song.title == "Blessed assurance")
        #expect(song.songType == .hymn)
        #expect(song.hymnNumber == "245")
        #expect(song.source == .logged)
        #expect(song.lastSungAt == date)
        #expect(part.librarySong === song)
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 1)
    }

    @Test func linkingReusesASongWithTheSameTitleAndType() throws {
        let context = try makeContext()
        let existing = LibrarySong(title: "Blessed Assurance", songType: .hymn, source: .added)
        context.insert(existing)
        let part = songPart(context, title: "blessed assurance", number: "245")
        SongLibrary.link(part, in: context)
        try context.save()
        #expect(part.librarySong === existing)
        // The library hymn learns its number from the service.
        #expect(existing.hymnNumber == "245")
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 1)

        // Same title as a chorus is a different song.
        let chorus = songPart(context, title: "Blessed assurance", type: .chorus)
        SongLibrary.link(chorus, in: context)
        try context.save()
        #expect(chorus.librarySong !== existing)
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 2)
    }

    @Test func retypingATitleRemovesTheUnusedLoggedSong() throws {
        let context = try makeContext()
        let part = songPart(context, title: "Gre")
        SongLibrary.link(part, in: context)
        try context.save()
        part.title = "Great is thy faithfulness"
        SongLibrary.link(part, in: context)
        try context.save()
        let titles = try context.fetch(FetchDescriptor<LibrarySong>()).map { $0.title }
        #expect(titles == ["Great is thy faithfulness"])
    }

    @Test func handAddedSongsStayWhenUnlinked() throws {
        let context = try makeContext()
        let added = LibrarySong(title: "Amazing grace", songType: .hymn, source: .added)
        context.insert(added)
        let part = songPart(context, title: "Amazing grace")
        SongLibrary.link(part, in: context)
        try context.save()
        #expect(part.librarySong === added)

        SongLibrary.partWillBeDeleted(part, in: context)
        context.delete(part)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 1)
    }

    @Test func adoptingASuggestionCopiesTitleTypeAndNumber() throws {
        let context = try makeContext()
        let library = LibrarySong(title: "It is well with my soul", songType: .hymn, hymnNumber: "301", source: .added)
        context.insert(library)
        let part = songPart(context, title: "it is", type: .chorus)
        SongLibrary.adopt(library, for: part, in: context)
        #expect(part.title == "It is well with my soul")
        #expect(part.songType == .hymn)
        #expect(part.hymnNumber == "301")
        #expect(part.librarySong === library)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Selah

struct ServicePartsLogicTests {
    @Test func headlinePrefersTheFirstTitledSermon() {
        let parts = [
            ServicePartSummary(kind: .song, title: "Great is thy faithfulness", hymnNumber: "12"),
            ServicePartSummary(kind: .bibleClass, title: "Ruth", person: "Sister B"),
            ServicePartSummary(kind: .sermon, title: " ", person: "Nobody"),
            ServicePartSummary(kind: .sermon, title: "Grace", person: "Pastor A")
        ]
        #expect(ServicesLogic.headline(parts: parts) == ServiceHeadline(title: "Grace", detail: "Pastor A"))
    }

    @Test func headlineFallsBackToTheFirstTitledPart() {
        let song = [ServicePartSummary(kind: .song, songType: .hymn, hymnNumber: "212")]
        #expect(ServicesLogic.headline(parts: song) == ServiceHeadline(title: "Hymn 212", detail: ""))
        let lesson = [
            ServicePartSummary(kind: .sermon, person: "Pastor A"),
            ServicePartSummary(kind: .bibleClass, title: "Ruth", person: "Sister B")
        ]
        #expect(ServicesLogic.headline(parts: lesson) == ServiceHeadline(title: "Ruth", detail: "Sister B"))
        #expect(ServicesLogic.headline(parts: []) == nil)
        #expect(ServicesLogic.headline(parts: [ServicePartSummary(kind: .sermon)]) == nil)
    }

    @Test func talksStartOpenAndFilledSongsStartClosed() {
        #expect(ServicesLogic.partStartsExpanded(kind: .sermon, hasContent: true))
        #expect(ServicesLogic.partStartsExpanded(kind: .bibleClass, hasContent: false))
        #expect(ServicesLogic.partStartsExpanded(kind: .song, hasContent: false))
        #expect(!ServicesLogic.partStartsExpanded(kind: .song, hasContent: true))
    }

    @Test func reorderedIndicesFollowListMove() {
        // Move the first row to the end (List reports destination = count).
        #expect(ServicesLogic.reorderedIndices(count: 4, from: IndexSet(integer: 0), to: 4) == [1, 2, 3, 0])
        // Move the last row to the top.
        #expect(ServicesLogic.reorderedIndices(count: 4, from: IndexSet(integer: 3), to: 0) == [3, 0, 1, 2])
        // Move row 1 below row 2.
        #expect(ServicesLogic.reorderedIndices(count: 4, from: IndexSet(integer: 1), to: 3) == [0, 2, 1, 3])
        // Nothing moves.
        #expect(ServicesLogic.reorderedIndices(count: 3, from: IndexSet(integer: 1), to: 1) == [0, 1, 2])
    }

    @Test func partHeadingsUsePlainWords() {
        #expect(ServicesLogic.partHeading(kind: .sermon, songType: .hymn) == "Sermon")
        #expect(ServicesLogic.partHeading(kind: .bibleClass, songType: .hymn) == "Bible class")
        #expect(ServicesLogic.partHeading(kind: .song, songType: .chorus) == "Chorus")
        #expect(ServicesLogic.partHeading(kind: .song, songType: .worship) == "Worship song")
    }
}

@MainActor
struct ServicePartsModelTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func orderedPartsFollowOrderAndNextOrderAppends() throws {
        let context = try makeContext()
        let service = Service(date: Date(), gatheringName: "Sunday worship")
        context.insert(service)
        let specs: [(Int, ServicePartKind)] = [(2, .song), (0, .sermon), (1, .bibleClass)]
        for (order, kind) in specs {
            let part = ServicePart(kind: kind, order: order)
            context.insert(part)
            part.service = service
        }
        try context.save()
        #expect(service.orderedParts.map { $0.kind } == [.sermon, .bibleClass, .song])
        #expect(service.nextPartOrder == 3)
        #expect(service.hasBibleClass)
        #expect(!service.hasFavouritePart)
    }

    @Test func deletingAServiceDeletesItsPartsButKeepsLibrarySongs() throws {
        let context = try makeContext()
        let service = Service(date: Date(), gatheringName: "Sunday worship")
        context.insert(service)
        let song = LibrarySong(title: "Amazing grace", source: .added)
        context.insert(song)
        let part = ServicePart(kind: .song, order: 0, title: "Amazing grace")
        context.insert(part)
        part.service = service
        part.librarySong = song
        let verse = VerseRef(book: "John", chapter: 1, verseStart: 1, verseEnd: 1, part: .sermon)
        let sermon = ServicePart(kind: .sermon, order: 1, title: "Word")
        context.insert(sermon)
        sermon.service = service
        context.insert(verse)
        verse.servicePart = sermon
        try context.save()

        context.delete(service)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ServicePart>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<VerseRef>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LibrarySong>()) == 1)
    }

    @Test func monthlySnapshotCountsEveryPart() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 12)) ?? Date()
        let service = Service(date: date, gatheringName: "Sunday worship")
        context.insert(service)
        let library = LibrarySong(title: "Great is thy faithfulness", hymnNumber: "12", source: .added)
        context.insert(library)
        let items: [ServicePart] = [
            ServicePart(kind: .sermon, order: 0, title: "Grace", person: "Pastor A"),
            ServicePart(kind: .sermon, order: 1, title: "Peace", person: "Pastor B"),
            ServicePart(kind: .bibleClass, order: 2, title: "Ruth"),
            ServicePart(kind: .song, order: 3, songType: .hymn, hymnNumber: "12"),
            ServicePart(kind: .song, order: 4, title: "This is the day", songType: .chorus, hymnNumber: "99"),
            // Added but left empty: not counted.
            ServicePart(kind: .sermon, order: 5)
        ]
        for part in items {
            context.insert(part)
            part.service = service
        }
        items[3].librarySong = library
        let verse = VerseRef(book: "Romans", chapter: 8, verseStart: 28, verseEnd: 28, part: .sermon)
        context.insert(verse)
        verse.servicePart = items[0]
        try context.save()

        let summary = MonthlySummary(services: [ServiceSnapshot(service)], month: date, calendar: calendar)
        #expect(summary.sermonCount == 2)
        #expect(summary.sermons.map { $0.title } == ["Grace", "Peace"])
        #expect(summary.classCount == 1)
        #expect(summary.songCount == 2)
        // A hymn logged by number takes its title from the library; chorus numbers are ignored.
        #expect(summary.songsSung.contains(MonthlySummary.SongCount(hymnNumber: "12", title: "Great is thy faithfulness", count: 1)))
        #expect(summary.songsSung.contains(MonthlySummary.SongCount(hymnNumber: "", title: "This is the day", count: 1)))
        #expect(summary.booksQuoted.map { $0.book } == ["Romans"])

        let export = ServiceExportItem(service)
        #expect(export.sermons.map { $0.title } == ["Grace", "Peace"])
        #expect(export.sermons.first?.verses == ["Romans 8:28"])
        #expect(export.classes.map { $0.title } == ["Ruth"])

        let note = NoteItem(service: service)
        #expect(note.title == "Grace")
        #expect(note.verseRefs == ["Romans 8:28"])
    }
}

import Foundation
import SwiftData
import Testing
@testable import Selah

@MainActor
struct ServicePartMigrationTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    // MARK: Pure mapping

    @Test func planOrdersSermonThenClassThenSongs() {
        let input = LegacyServiceInput(
            sermonTitle: " Grace ", sermonist: "Pastor A",
            classLesson: "Ruth", classTeacher: "Sister B",
            songs: [
                .init(hymnNumber: "30", title: "Second", order: 1),
                .init(hymnNumber: "12", title: "First", order: 0)
            ]
        )
        let plan = ServicePartMigration.plan(input)
        #expect(plan.map { $0.kind } == [.sermon, .bibleClass, .song, .song])
        #expect(plan.map { $0.order } == [0, 1, 2, 3])
        #expect(plan[0].title == "Grace")
        #expect(plan[0].person == "Pastor A")
        #expect(plan[1].title == "Ruth")
        #expect(plan[2].title == "First")
        #expect(plan[2].source == .song(1))
        #expect(plan[3].title == "Second")
    }

    @Test func planSkipsEmptySectionsAndBlankSongs() {
        let input = LegacyServiceInput(
            classLesson: "Ruth",
            songs: [.init(hymnNumber: " ", title: "  ", order: 0), .init(title: "How great", order: 1)]
        )
        let plan = ServicePartMigration.plan(input)
        #expect(plan.map { $0.kind } == [.bibleClass, .song])
        #expect(plan.map { $0.order } == [0, 1])
        #expect(ServicePartMigration.plan(LegacyServiceInput()).isEmpty)
    }

    @Test func planKeepsSectionsWithOnlyNotesVersesStarsOrComments() {
        #expect(ServicePartMigration.plan(LegacyServiceInput(sermonHasNote: true)).map { $0.kind } == [.sermon])
        #expect(ServicePartMigration.plan(LegacyServiceInput(sermonVerseCount: 1)).map { $0.kind } == [.sermon])
        #expect(ServicePartMigration.plan(LegacyServiceInput(classFavourite: true)).map { $0.kind } == [.bibleClass])
        #expect(ServicePartMigration.plan(LegacyServiceInput(classCommentCount: 1)).map { $0.kind } == [.bibleClass])
        let starred = ServicePartMigration.plan(LegacyServiceInput(sermonTitle: "Joy", sermonFavourite: true))
        #expect(starred.first?.isFavourite == true)
    }

    @Test func planTypesSongsByNumber() {
        let plan = ServicePartMigration.plan(LegacyServiceInput(songs: [
            .init(hymnNumber: "212", title: "Hymn song", order: 0),
            .init(hymnNumber: "", title: "Chorus song", order: 1)
        ]))
        #expect(plan.map { $0.songType } == [.hymn, .chorus])
        #expect(plan[0].hymnNumber == "212")
    }

    // MARK: Applying to the store

    private func legacyService(_ context: ModelContext, date: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> Service {
        var note = AttributedString("Grace and peace")
        if let range = note.range(of: "peace") {
            HighlightLogic.apply(id: "h1", to: range, in: &note)
        }
        let service = Service(
            date: date,
            gatheringName: "Sunday worship",
            sermonTitle: "Joy",
            sermonist: "Elder Mensah",
            sermonNote: note,
            sermonFavourite: true,
            classLesson: "Prayer",
            classTeacher: "Sister Ama",
            classNote: AttributedString("Pray always")
        )
        context.insert(service)
        let sermonVerse = VerseRef(book: "John", chapter: 3, verseStart: 16, verseEnd: 16, part: .sermon)
        let classVerse = VerseRef(book: "Matthew", chapter: 6, verseStart: 9, verseEnd: 9, part: .bibleClass)
        context.insert(sermonVerse)
        context.insert(classVerse)
        service.verses.append(sermonVerse)
        service.verses.append(classVerse)
        let comment = NoteComment(highlightID: "h1", quotedText: "peace", comment: "Rest", field: .sermon)
        context.insert(comment)
        service.comments.append(comment)
        for (index, item) in [("12", "Great is thy faithfulness"), ("", "This is the day")].enumerated() {
            let song = Song(hymnNumber: item.0, title: item.1, order: index)
            context.insert(song)
            service.songs.append(song)
        }
        return service
    }

    @Test func migrationMovesNotesVersesAndComments() throws {
        let context = try makeContext()
        let service = legacyService(context)
        try context.save()

        #expect(ServicePartMigration.migrateAll(in: context) == 1)
        try context.save()

        let parts = service.orderedParts
        #expect(parts.map { $0.kind } == [.sermon, .bibleClass, .song, .song])
        let sermon = parts[0]
        #expect(sermon.title == "Joy")
        #expect(sermon.person == "Elder Mensah")
        #expect(sermon.isFavourite)
        #expect(sermon.verses.map { $0.reference } == ["John 3:16"])
        #expect(sermon.comments.count == 1)
        #expect(sermon.comments.first?.field == .body)
        #expect(HighlightLogic.orderedIDs(in: sermon.notes) == ["h1"])
        let bibleClass = parts[1]
        #expect(bibleClass.title == "Prayer")
        #expect(bibleClass.verses.map { $0.reference } == ["Matthew 6:9"])
        #expect(String(bibleClass.notes.characters) == "Pray always")
        #expect(parts[2].songType == .hymn)
        #expect(parts[2].hymnNumber == "12")
        #expect(parts[3].songType == .chorus)
        #expect(service.verses.isEmpty)
        #expect(service.comments.isEmpty)
        #expect(service.partsMigrated)
        // The old fields are kept, not cleared.
        #expect(service.sermonTitle == "Joy")
    }

    @Test func migrationIsIdempotentAndNeverBringsBackDeletedParts() throws {
        let context = try makeContext()
        let service = legacyService(context)
        try context.save()
        ServicePartMigration.migrateAll(in: context)
        try context.save()
        #expect(service.parts.count == 4)

        #expect(ServicePartMigration.migrateAll(in: context) == 0)
        #expect(service.parts.count == 4)

        // The user deletes every part; the old fields must not refill the service.
        for part in service.parts { context.delete(part) }
        try context.save()
        #expect(ServicePartMigration.migrateAll(in: context) == 0)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ServicePart>()) == 0)
    }

    @Test func emptyServiceIsMarkedWithoutParts() throws {
        let context = try makeContext()
        let service = Service(date: Date(), gatheringName: "Prayer meeting")
        context.insert(service)
        #expect(ServicePartMigration.migrateAll(in: context) == 0)
        #expect(service.partsMigrated)
        #expect(service.parts.isEmpty)
    }

    @Test func migrationLinksSongsToTheLibrary() throws {
        let context = try makeContext()
        let existing = LibrarySong(title: "Great Is Thy Faithfulness!", songType: .hymn, hymnNumber: "12", source: .added)
        context.insert(existing)
        let first = legacyService(context, date: Date(timeIntervalSince1970: 1_700_000_000))
        let second = legacyService(context, date: Date(timeIntervalSince1970: 1_700_600_000))
        try context.save()

        ServicePartMigration.migrateAll(in: context)
        try context.save()

        let library = try context.fetch(FetchDescriptor<LibrarySong>())
        // "Great is thy faithfulness" reuses the hand-added song; "This is the day" is created once and shared.
        #expect(library.count == 2)
        let hymn = try #require(first.orderedParts(of: .song).first?.librarySong)
        #expect(hymn === existing)
        #expect(existing.timesSung == 2)
        #expect(existing.lastSungAt == second.date)
        let chorus = try #require(second.orderedParts(of: .song).last?.librarySong)
        #expect(chorus.title == "This is the day")
        #expect(chorus.songType == .chorus)
        #expect(chorus.source == .logged)
        #expect(chorus.timesSung == 2)
    }
}

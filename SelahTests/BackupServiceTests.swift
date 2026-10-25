import Foundation
import SwiftData
import Testing
@testable import Selah

@MainActor
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func count<T: PersistentModel>(_ type: T.Type, _ context: ModelContext) throws -> Int {
        try context.fetchCount(FetchDescriptor<T>())
    }

    private func richText(highlightID: String) -> AttributedString {
        var text = AttributedString("Grace and peace")
        if let range = text.range(of: "peace") {
            HighlightLogic.apply(id: highlightID, to: range, in: &text)
        }
        return text
    }

    /// A small but complete data set that touches every model (services recorded with parts).
    private func populate(_ context: ModelContext, highlightID: String) throws {
        let profile = UserProfile(name: "Ama", congregation: "Accra", translation: .bsb, textSize: 22, appearance: .dark, onboarded: true)
        context.insert(profile)
        context.insert(MeetingDay(weekday: 1, hour: 9, minute: 30, name: "Sunday service"))

        let plan = ReadingPlan(bookName: "Philippians", totalChapters: 4, status: .reading, plannedDays: 14, chaptersRead: [1, 2])
        context.insert(plan)
        let reminder = ReadingReminder(hour: 6, minute: 45, notificationID: "reminder-1")
        context.insert(reminder)
        plan.reminders.append(reminder)

        let entry = StudyEntry(date: Date(timeIntervalSince1970: 1_700_000_000), chapter: 2, note: richText(highlightID: highlightID))
        context.insert(entry)
        plan.entries.append(entry)
        let best = VerseRef(book: "Philippians", chapter: 2, verseStart: 3, verseEnd: 4, translation: .kjv, textSnapshot: "Let nothing be done through strife", part: .none)
        context.insert(best)
        entry.bestVerse = best
        let comment = NoteComment(highlightID: highlightID, quotedText: "peace", comment: "Rest in it", field: .body)
        context.insert(comment)
        entry.comments.append(comment)

        let service = Service(date: Date(timeIntervalSince1970: 1_700_100_000), gatheringName: "Sunday")
        service.partsMigrated = true
        context.insert(service)
        let sermon = ServicePart(
            kind: .sermon,
            order: 0,
            title: "Joy",
            person: "Elder Mensah",
            notes: richText(highlightID: "sermon-highlight"),
            isFavourite: true
        )
        context.insert(sermon)
        sermon.service = service
        let serviceVerse = VerseRef(book: "John", chapter: 3, verseStart: 16, verseEnd: 16, textSnapshot: "For God so loved the world", part: .sermon)
        context.insert(serviceVerse)
        sermon.verses.append(serviceVerse)
        let sermonComment = NoteComment(highlightID: "sermon-highlight", quotedText: "peace", comment: "Shalom", field: .body)
        context.insert(sermonComment)
        sermon.comments.append(sermonComment)

        let blessed = LibrarySong(
            title: "Blessed assurance",
            songType: .hymn,
            hymnNumber: "245",
            lyricVerses: ["Blessed assurance, Jesus is mine!", "Perfect submission, perfect delight,"],
            refrain: "This is my story, this is my song,",
            source: .logged
        )
        let chorus = LibrarySong(title: "This is the day", songType: .chorus, source: .logged)
        let added = LibrarySong(title: "Amazing grace", songType: .hymn, source: .added)
        for song in [blessed, chorus, added] { context.insert(song) }
        let hymnPart = ServicePart(kind: .song, order: 1, title: "Blessed assurance", songType: .hymn, hymnNumber: "245")
        let chorusPart = ServicePart(kind: .song, order: 2, title: "This is the day", songType: .chorus)
        for part in [hymnPart, chorusPart] {
            context.insert(part)
            part.service = service
        }
        hymnPart.librarySong = blessed
        chorusPart.librarySong = chorus

        let note = PersonalNote(title: "Prayer list", body: AttributedString("Pray daily"), colour: .sky, pinned: true)
        context.insert(note)
        let noteVerse = VerseRef(book: "Psalms", chapter: 23, verseStart: 1, verseEnd: 1, textSnapshot: "The Lord is my shepherd")
        context.insert(noteVerse)
        note.verses.append(noteVerse)
        let noteComment = NoteComment(quotedText: "daily", comment: "Every morning", field: .body)
        context.insert(noteComment)
        note.comments.append(noteComment)

        try context.save()
    }

    @Test func backupSurvivesWipeAndRestoreIntoFreshStore() throws {
        let highlightID = "highlight-123"
        let source = try makeContext()
        try populate(source, highlightID: highlightID)

        let backup = try BackupService.makeBackup(from: source, now: Date(timeIntervalSince1970: 1_800_000_000))
        let data = try BackupService.encode(backup)

        // Wipe the source to prove the file stands alone.
        try BackupService.restore(Backup(version: 1, exportedAt: Date(), profile: nil, meetingDays: [], plans: [], services: [], personalNotes: []), into: source)
        #expect(try count(ReadingPlan.self, source) == 0)
        #expect(try count(VerseRef.self, source) == 0)

        let fresh = try makeContext()
        let decoded = try BackupService.decode(data)
        let counts = try BackupService.restore(decoded, into: fresh)

        #expect(counts.books == 1)
        #expect(counts.entries == 1)
        #expect(counts.services == 1)
        #expect(counts.notes == 1)
        #expect(counts.meetingDays == 1)

        #expect(try count(UserProfile.self, fresh) == 1)
        #expect(try count(MeetingDay.self, fresh) == 1)
        #expect(try count(ReadingPlan.self, fresh) == 1)
        #expect(try count(ReadingReminder.self, fresh) == 1)
        #expect(try count(StudyEntry.self, fresh) == 1)
        #expect(try count(Service.self, fresh) == 1)
        #expect(try count(Song.self, fresh) == 0)
        #expect(try count(ServicePart.self, fresh) == 3)
        #expect(try count(LibrarySong.self, fresh) == 3)
        #expect(try count(PersonalNote.self, fresh) == 1)
        #expect(try count(VerseRef.self, fresh) == 3)
        #expect(try count(NoteComment.self, fresh) == 3)

        let plan = try #require(try fresh.fetch(FetchDescriptor<ReadingPlan>()).first)
        #expect(plan.bookName == "Philippians")
        #expect(plan.chaptersRead == [1, 2])
        #expect(plan.reminders.count == 1)
        #expect(plan.reminders.first?.notificationID == "reminder-1")

        let entry = try #require(plan.entries.first)
        #expect(entry.bestVerse?.reference == "Philippians 2:3-4")
        #expect(entry.comments.count == 1)
        #expect(entry.comments.first?.highlightID == highlightID)

        // The rich note keeps its highlight ID.
        let highlighted = HighlightLogic.orderedIDs(in: entry.note)
        #expect(highlighted == [highlightID])

        let service = try #require(try fresh.fetch(FetchDescriptor<Service>()).first)
        #expect(service.partsMigrated)
        let parts = service.orderedParts
        #expect(parts.map { $0.kind } == [.sermon, .song, .song])
        let sermon = parts[0]
        #expect(sermon.isFavourite)
        #expect(sermon.person == "Elder Mensah")
        #expect(sermon.verses.map { $0.reference } == ["John 3:16"])
        #expect(sermon.comments.first?.highlightID == "sermon-highlight")
        #expect(HighlightLogic.orderedIDs(in: sermon.notes) == ["sermon-highlight"])
        #expect(parts[1].hymnNumber == "245")
        #expect(parts[2].songType == .chorus)

        let library = try fresh.fetch(FetchDescriptor<LibrarySong>())
        let blessed = try #require(library.first { $0.title == "Blessed assurance" })
        #expect(parts[1].librarySong === blessed)
        #expect(blessed.lyricVerses.count == 2)
        #expect(blessed.refrain == "This is my story, this is my song,")
        #expect(blessed.timesSung == 1)
        let added = try #require(library.first { $0.title == "Amazing grace" })
        #expect(added.source == .added)
        #expect(added.timesSung == 0)

        let note = try #require(try fresh.fetch(FetchDescriptor<PersonalNote>()).first)
        #expect(note.colour == .sky)
        #expect(note.pinned)
        #expect(note.verses.count == 1)
        #expect(note.comments.count == 1)

        let profile = try #require(try fresh.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.name == "Ama")
        #expect(profile.translation == .bsb)
        #expect(profile.appearance == .dark)
    }

    @Test func restoreReplacesExistingData() throws {
        let context = try makeContext()
        try populate(context, highlightID: "a")
        let backup = try BackupService.makeBackup(from: context)
        // Add extra rows, then restore: the extras must disappear.
        context.insert(ReadingPlan(bookName: "Extra", totalChapters: 1))
        context.insert(Service(gatheringName: "Extra"))
        context.insert(LibrarySong(title: "Extra song", source: .added))
        try context.save()

        try BackupService.restore(backup, into: context)

        #expect(try count(ReadingPlan.self, context) == 1)
        #expect(try count(Service.self, context) == 1)
        #expect(try count(LibrarySong.self, context) == 3)
        #expect(try count(UserProfile.self, context) == 1)
    }

    /// A backup made before service parts (no parts, no library) restores and is migrated into parts.
    @Test func oldBackupWithoutPartsIsMigratedOnRestore() throws {
        let source = try makeContext()
        let service = Service(
            date: Date(timeIntervalSince1970: 1_700_100_000),
            gatheringName: "Sunday",
            sermonTitle: "Joy",
            sermonist: "Elder Mensah",
            sermonNote: richText(highlightID: "old-highlight"),
            sermonFavourite: true,
            classLesson: "Prayer",
            classTeacher: "Sister Ama"
        )
        source.insert(service)
        for (index, title) in ["Amazing Grace", "How Great Thou Art"].enumerated() {
            let song = Song(hymnNumber: "\(index + 1)", title: title, order: index)
            source.insert(song)
            service.songs.append(song)
        }
        let verse = VerseRef(book: "John", chapter: 3, verseStart: 16, verseEnd: 16, part: .sermon)
        source.insert(verse)
        service.verses.append(verse)
        let comment = NoteComment(highlightID: "old-highlight", quotedText: "peace", comment: "Rest", field: .sermon)
        source.insert(comment)
        service.comments.append(comment)
        try source.save()

        // Strip the new keys, as an old version of Selah would have written the file.
        var backup = try BackupService.makeBackup(from: source)
        backup.librarySongs = nil
        for index in backup.services.indices {
            backup.services[index].parts = nil
            backup.services[index].partsMigrated = nil
        }
        let data = try BackupService.encode(backup)
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("partsMigrated"))
        #expect(!json.contains("librarySongs"))

        let fresh = try makeContext()
        try BackupService.restore(try BackupService.decode(data), into: fresh)

        let restored = try #require(try fresh.fetch(FetchDescriptor<Service>()).first)
        #expect(restored.partsMigrated)
        let parts = restored.orderedParts
        #expect(parts.map { $0.kind } == [.sermon, .bibleClass, .song, .song])
        #expect(parts[0].title == "Joy")
        #expect(parts[0].isFavourite)
        #expect(parts[0].verses.count == 1)
        #expect(parts[0].comments.count == 1)
        #expect(parts[1].person == "Sister Ama")
        #expect(parts[2].hymnNumber == "1")
        #expect(restored.verses.isEmpty)
        #expect(try count(LibrarySong.self, fresh) == 2)
        #expect(parts[3].librarySong?.title == "How Great Thou Art")
    }

    @Test func decodeRejectsBadFilesWithPlainErrors() throws {
        #expect(throws: BackupError.notABackup) {
            try BackupService.decode(Data("hello".utf8))
        }
        #expect(throws: BackupError.newerVersion) {
            try BackupService.decode(Data(#"{"version": 99}"#.utf8))
        }
        #expect(throws: BackupError.notABackup) {
            try BackupService.decode(Data(#"{"version": 1}"#.utf8))
        }
    }

    @Test func backupFileIsNamedByDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 12)) ?? Date()
        #expect(BackupService.fileName(for: date, calendar: calendar) == "Selah backup 2026-10-18.json")
    }
}

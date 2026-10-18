import Foundation
import SwiftData

// MARK: - Backup file format (version 1)

/// The whole app as plain Codable values. Rich note text is kept as the same encoded `Data` the models store,
/// so formatting and highlight IDs come back exactly.
struct Backup: Codable, Sendable, Equatable {
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var profile: ProfileDTO?
    var meetingDays: [MeetingDayDTO]
    var plans: [PlanDTO]
    var services: [ServiceDTO]
    var personalNotes: [PersonalNoteDTO]

    struct ProfileDTO: Codable, Sendable, Equatable {
        var name: String
        var photoData: Data?
        var congregation: String
        var translation: Translation
        var textSize: Double
        var appearance: Appearance
        var onboarded: Bool
    }

    struct MeetingDayDTO: Codable, Sendable, Equatable {
        var weekday: Int
        var hour: Int
        var minute: Int
        var name: String
        var reminderMinutesBefore: Int
        var isActive: Bool
    }

    struct VerseDTO: Codable, Sendable, Equatable {
        var book: String
        var chapter: Int
        var verseStart: Int
        var verseEnd: Int
        var translation: Translation
        var textSnapshot: String
        var part: VersePart
    }

    struct CommentDTO: Codable, Sendable, Equatable {
        var highlightID: String
        var quotedText: String
        var comment: String
        var createdAt: Date
        var field: CommentField
    }

    struct SongDTO: Codable, Sendable, Equatable {
        var hymnNumber: String
        var title: String
        var order: Int
    }

    struct ReminderDTO: Codable, Sendable, Equatable {
        var hour: Int
        var minute: Int
        var notificationID: String
    }

    struct EntryDTO: Codable, Sendable, Equatable {
        var date: Date
        var chapter: Int
        var noteData: Data
        var createdAt: Date
        var bestVerse: VerseDTO?
        var comments: [CommentDTO]
    }

    struct PlanDTO: Codable, Sendable, Equatable {
        var bookName: String
        var totalChapters: Int
        var status: ReadingStatus
        var plannedDays: Int
        var startDate: Date?
        var finishedDate: Date?
        var chaptersRead: [Int]
        var reminders: [ReminderDTO]
        var entries: [EntryDTO]
        /// Added in Round 2. Optional, so older backups still decode.
        var bannerData: Data? = nil
        var toneRaw: String? = nil
    }

    struct ServiceDTO: Codable, Sendable, Equatable {
        var date: Date
        var gatheringName: String
        var sermonTitle: String
        var sermonist: String
        var sermonNoteData: Data
        var sermonFavourite: Bool
        var classLesson: String
        var classTeacher: String
        var classNoteData: Data
        var classFavourite: Bool
        var songs: [SongDTO]
        var verses: [VerseDTO]
        var comments: [CommentDTO]
    }

    struct PersonalNoteDTO: Codable, Sendable, Equatable {
        var title: String
        var bodyData: Data
        var colour: NoteColour
        var pinned: Bool
        var updatedAt: Date
        var verses: [VerseDTO]
        var comments: [CommentDTO]
    }
}

/// How many things a restore brought back.
struct RestoreCounts: Sendable, Equatable {
    var books = 0
    var entries = 0
    var services = 0
    var notes = 0
    var meetingDays = 0

    /// Plain words, for example "3 books, 12 entries, 4 services, 2 notes and 2 meeting days".
    var summary: String {
        let parts = [
            "\(books) \(books == 1 ? "book" : "books")",
            "\(entries) \(entries == 1 ? "entry" : "entries")",
            "\(services) \(services == 1 ? "service" : "services")",
            "\(notes) \(notes == 1 ? "note" : "notes")",
            "\(meetingDays) \(meetingDays == 1 ? "meeting day" : "meeting days")"
        ]
        return parts.dropLast().joined(separator: ", ") + " and " + (parts.last ?? "")
    }
}

enum BackupError: LocalizedError, Equatable {
    case cannotRead
    case notABackup
    case newerVersion
    case cannotSave

    var errorDescription: String? {
        switch self {
        case .cannotRead: return "Selah couldn't open that file."
        case .notABackup: return "That file isn't a Selah backup."
        case .newerVersion: return "That backup was made by a newer version of Selah. Update Selah and try again."
        case .cannotSave: return "Selah couldn't restore the backup. Your data was left as it was."
        }
    }
}

// MARK: - Service

@MainActor
enum BackupService {
    // MARK: Export

    static func makeBackup(from context: ModelContext, now: Date = Date()) throws -> Backup {
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        let meetingDays = try context.fetch(FetchDescriptor<MeetingDay>())
        let plans = try context.fetch(FetchDescriptor<ReadingPlan>())
        let services = try context.fetch(FetchDescriptor<Service>())
        let notes = try context.fetch(FetchDescriptor<PersonalNote>())

        return Backup(
            version: Backup.currentVersion,
            exportedAt: now,
            profile: profile.map(profileDTO),
            meetingDays: meetingDays
                .sorted { ($0.weekday, $0.hour, $0.minute) < ($1.weekday, $1.hour, $1.minute) }
                .map(meetingDayDTO),
            plans: plans.sorted { $0.bookName < $1.bookName }.map(planDTO),
            services: services.sorted { $0.date < $1.date }.map(serviceDTO),
            personalNotes: notes.sorted { $0.updatedAt < $1.updatedAt }.map(noteDTO)
        )
    }

    static func encode(_ backup: Backup) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    static func fileName(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return "Selah backup \(formatter.string(from: date)).json"
    }

    /// Writes the backup to the temporary folder and returns the file's URL.
    static func writeBackupFile(from context: ModelContext, now: Date = Date()) throws -> URL {
        let data = try encode(try makeBackup(from: context, now: now))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: now))
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Read

    private struct Header: Decodable {
        var version: Int
    }

    static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let header = try? decoder.decode(Header.self, from: data) else {
            throw BackupError.notABackup
        }
        guard header.version >= 1 else { throw BackupError.notABackup }
        guard header.version <= Backup.currentVersion else { throw BackupError.newerVersion }
        guard let backup = try? decoder.decode(Backup.self, from: data) else {
            throw BackupError.notABackup
        }
        return backup
    }

    /// Reads a file picked with the file importer (handles the security-scoped access).
    static func readBackup(from url: URL) throws -> Backup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped { url.stopAccessingSecurityScopedResource() }
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw BackupError.cannotRead
        }
        return try decode(data)
    }

    // MARK: Restore

    /// Replaces everything in the store with the backup. If saving fails, the changes are rolled back.
    @discardableResult
    static func restore(_ backup: Backup, into context: ModelContext) throws -> RestoreCounts {
        do {
            try deleteEverything(in: context)
            let counts = insert(backup, into: context)
            try context.save()
            return counts
        } catch {
            context.rollback()
            throw BackupError.cannotSave
        }
    }

    private static func deleteEverything(in context: ModelContext) throws {
        // Roots first (cascade removes their children), then anything left over.
        try deleteAll(ReadingPlan.self, in: context)
        try deleteAll(Service.self, in: context)
        try deleteAll(PersonalNote.self, in: context)
        try deleteAll(MeetingDay.self, in: context)
        try context.save()
        try deleteAll(StudyEntry.self, in: context)
        try deleteAll(ReadingReminder.self, in: context)
        try deleteAll(VerseRef.self, in: context)
        try deleteAll(NoteComment.self, in: context)
        try deleteAll(Song.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for item in try context.fetch(FetchDescriptor<T>()) {
            context.delete(item)
        }
    }

    private static func insert(_ backup: Backup, into context: ModelContext) -> RestoreCounts {
        var counts = RestoreCounts()

        if let dto = backup.profile {
            let existing = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
            let profile = existing ?? UserProfile()
            if existing == nil { context.insert(profile) }
            profile.name = dto.name
            profile.photoData = dto.photoData
            profile.congregation = dto.congregation
            profile.translation = dto.translation
            profile.textSize = dto.textSize
            profile.appearance = dto.appearance
            profile.onboarded = dto.onboarded
        }

        for dto in backup.meetingDays {
            context.insert(MeetingDay(
                weekday: dto.weekday,
                hour: dto.hour,
                minute: dto.minute,
                name: dto.name,
                reminderMinutesBefore: dto.reminderMinutesBefore,
                isActive: dto.isActive
            ))
            counts.meetingDays += 1
        }

        for dto in backup.plans {
            let plan = ReadingPlan(
                bookName: dto.bookName,
                totalChapters: dto.totalChapters,
                status: dto.status,
                plannedDays: dto.plannedDays,
                startDate: dto.startDate,
                finishedDate: dto.finishedDate,
                chaptersRead: dto.chaptersRead
            )
            plan.bannerData = dto.bannerData
            if let toneRaw = dto.toneRaw { plan.toneRaw = toneRaw }
            context.insert(plan)
            counts.books += 1

            for reminderDTO in dto.reminders {
                let reminder = ReadingReminder(
                    hour: reminderDTO.hour,
                    minute: reminderDTO.minute,
                    notificationID: reminderDTO.notificationID
                )
                context.insert(reminder)
                plan.reminders.append(reminder)
            }

            for entryDTO in dto.entries {
                let entry = StudyEntry(date: entryDTO.date, chapter: entryDTO.chapter, createdAt: entryDTO.createdAt)
                entry.noteData = entryDTO.noteData
                context.insert(entry)
                plan.entries.append(entry)
                counts.entries += 1

                if let verseDTO = entryDTO.bestVerse {
                    let verse = makeVerse(verseDTO)
                    context.insert(verse)
                    entry.bestVerse = verse
                }
                for commentDTO in entryDTO.comments {
                    let comment = makeComment(commentDTO)
                    context.insert(comment)
                    entry.comments.append(comment)
                }
            }
        }

        for dto in backup.services {
            let service = Service(
                date: dto.date,
                gatheringName: dto.gatheringName,
                sermonTitle: dto.sermonTitle,
                sermonist: dto.sermonist,
                sermonFavourite: dto.sermonFavourite,
                classLesson: dto.classLesson,
                classTeacher: dto.classTeacher,
                classFavourite: dto.classFavourite
            )
            service.sermonNoteData = dto.sermonNoteData
            service.classNoteData = dto.classNoteData
            context.insert(service)
            counts.services += 1

            for songDTO in dto.songs {
                let song = Song(hymnNumber: songDTO.hymnNumber, title: songDTO.title, order: songDTO.order)
                context.insert(song)
                service.songs.append(song)
            }
            for verseDTO in dto.verses {
                let verse = makeVerse(verseDTO)
                context.insert(verse)
                service.verses.append(verse)
            }
            for commentDTO in dto.comments {
                let comment = makeComment(commentDTO)
                context.insert(comment)
                service.comments.append(comment)
            }
        }

        for dto in backup.personalNotes {
            let note = PersonalNote(title: dto.title, colour: dto.colour, pinned: dto.pinned, updatedAt: dto.updatedAt)
            note.bodyData = dto.bodyData
            context.insert(note)
            counts.notes += 1

            for verseDTO in dto.verses {
                let verse = makeVerse(verseDTO)
                context.insert(verse)
                note.verses.append(verse)
            }
            for commentDTO in dto.comments {
                let comment = makeComment(commentDTO)
                context.insert(comment)
                note.comments.append(comment)
            }
        }
        return counts
    }

    // MARK: Model <-> DTO

    private static func makeVerse(_ dto: Backup.VerseDTO) -> VerseRef {
        VerseRef(
            book: dto.book,
            chapter: dto.chapter,
            verseStart: dto.verseStart,
            verseEnd: dto.verseEnd,
            translation: dto.translation,
            textSnapshot: dto.textSnapshot,
            part: dto.part
        )
    }

    private static func makeComment(_ dto: Backup.CommentDTO) -> NoteComment {
        NoteComment(
            highlightID: dto.highlightID,
            quotedText: dto.quotedText,
            comment: dto.comment,
            createdAt: dto.createdAt,
            field: dto.field
        )
    }

    private static func verseDTO(_ verse: VerseRef) -> Backup.VerseDTO {
        Backup.VerseDTO(
            book: verse.book,
            chapter: verse.chapter,
            verseStart: verse.verseStart,
            verseEnd: verse.verseEnd,
            translation: verse.translation,
            textSnapshot: verse.textSnapshot,
            part: verse.part
        )
    }

    private static func commentDTO(_ comment: NoteComment) -> Backup.CommentDTO {
        Backup.CommentDTO(
            highlightID: comment.highlightID,
            quotedText: comment.quotedText,
            comment: comment.comment,
            createdAt: comment.createdAt,
            field: comment.field
        )
    }

    private static func profileDTO(_ profile: UserProfile) -> Backup.ProfileDTO {
        Backup.ProfileDTO(
            name: profile.name,
            photoData: profile.photoData,
            congregation: profile.congregation,
            translation: profile.translation,
            textSize: profile.textSize,
            appearance: profile.appearance,
            onboarded: profile.onboarded
        )
    }

    private static func meetingDayDTO(_ day: MeetingDay) -> Backup.MeetingDayDTO {
        Backup.MeetingDayDTO(
            weekday: day.weekday,
            hour: day.hour,
            minute: day.minute,
            name: day.name,
            reminderMinutesBefore: day.reminderMinutesBefore,
            isActive: day.isActive
        )
    }

    private static func planDTO(_ plan: ReadingPlan) -> Backup.PlanDTO {
        Backup.PlanDTO(
            bookName: plan.bookName,
            totalChapters: plan.totalChapters,
            status: plan.status,
            plannedDays: plan.plannedDays,
            startDate: plan.startDate,
            finishedDate: plan.finishedDate,
            chaptersRead: plan.chaptersRead,
            reminders: plan.reminders
                .sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
                .map { Backup.ReminderDTO(hour: $0.hour, minute: $0.minute, notificationID: $0.notificationID) },
            entries: plan.entries
                .sorted { $0.date < $1.date }
                .map(entryDTO),
            bannerData: plan.bannerData,
            toneRaw: plan.toneRaw
        )
    }

    private static func entryDTO(_ entry: StudyEntry) -> Backup.EntryDTO {
        Backup.EntryDTO(
            date: entry.date,
            chapter: entry.chapter,
            noteData: entry.noteData,
            createdAt: entry.createdAt,
            bestVerse: entry.bestVerse.map(verseDTO),
            comments: entry.comments.sorted { $0.createdAt < $1.createdAt }.map(commentDTO)
        )
    }

    private static func serviceDTO(_ service: Service) -> Backup.ServiceDTO {
        Backup.ServiceDTO(
            date: service.date,
            gatheringName: service.gatheringName,
            sermonTitle: service.sermonTitle,
            sermonist: service.sermonist,
            sermonNoteData: service.sermonNoteData,
            sermonFavourite: service.sermonFavourite,
            classLesson: service.classLesson,
            classTeacher: service.classTeacher,
            classNoteData: service.classNoteData,
            classFavourite: service.classFavourite,
            songs: service.songs.sorted { $0.order < $1.order }
                .map { Backup.SongDTO(hymnNumber: $0.hymnNumber, title: $0.title, order: $0.order) },
            verses: service.verses.map(verseDTO),
            comments: service.comments.sorted { $0.createdAt < $1.createdAt }.map(commentDTO)
        )
    }

    private static func noteDTO(_ note: PersonalNote) -> Backup.PersonalNoteDTO {
        Backup.PersonalNoteDTO(
            title: note.title,
            bodyData: note.bodyData,
            colour: note.colour,
            pinned: note.pinned,
            updatedAt: note.updatedAt,
            verses: note.verses.map(verseDTO),
            comments: note.comments.sorted { $0.createdAt < $1.createdAt }.map(commentDTO)
        )
    }
}

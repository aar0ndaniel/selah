import Foundation
import SwiftData

// One-time move from the old service layout (one sermon, one Bible class, a song list) to parts.
//
// - Runs on launch (RootTabView) and after a restore, on the main actor. Idempotent: a service is looked at once
//   (`Service.partsMigrated`), so a part the user deletes later never comes back.
// - Nothing is lost: legacy text stays in the old fields (no longer written or shown); verses and comments are
//   moved to the new part; every song gets a part and a library song (an existing one with the same title and type
//   is reused).
// - `plan(_:)` is the pure mapping (unit tested); `migrate(_:in:library:)` applies it to the models.

/// Plain value copy of a service in the old layout.
struct LegacyServiceInput: Sendable, Equatable {
    struct SongInput: Sendable, Equatable {
        var hymnNumber: String
        var title: String
        var order: Int

        init(hymnNumber: String = "", title: String = "", order: Int = 0) {
            self.hymnNumber = hymnNumber
            self.title = title
            self.order = order
        }
    }

    var sermonTitle: String
    var sermonist: String
    var sermonHasNote: Bool
    var sermonFavourite: Bool
    /// Verses marked `.sermon` (and unmarked `.none` ones, which belong with the sermon).
    var sermonVerseCount: Int
    var sermonCommentCount: Int
    var classLesson: String
    var classTeacher: String
    var classHasNote: Bool
    var classFavourite: Bool
    var classVerseCount: Int
    var classCommentCount: Int
    var songs: [SongInput]

    init(
        sermonTitle: String = "",
        sermonist: String = "",
        sermonHasNote: Bool = false,
        sermonFavourite: Bool = false,
        sermonVerseCount: Int = 0,
        sermonCommentCount: Int = 0,
        classLesson: String = "",
        classTeacher: String = "",
        classHasNote: Bool = false,
        classFavourite: Bool = false,
        classVerseCount: Int = 0,
        classCommentCount: Int = 0,
        songs: [SongInput] = []
    ) {
        self.sermonTitle = sermonTitle
        self.sermonist = sermonist
        self.sermonHasNote = sermonHasNote
        self.sermonFavourite = sermonFavourite
        self.sermonVerseCount = sermonVerseCount
        self.sermonCommentCount = sermonCommentCount
        self.classLesson = classLesson
        self.classTeacher = classTeacher
        self.classHasNote = classHasNote
        self.classFavourite = classFavourite
        self.classVerseCount = classVerseCount
        self.classCommentCount = classCommentCount
        self.songs = songs
    }
}

/// One part the migration will create.
struct PlannedServicePart: Sendable, Equatable {
    enum Source: Sendable, Equatable {
        case sermon
        case bibleClass
        /// Index into `LegacyServiceInput.songs`.
        case song(Int)
    }

    var source: Source
    var kind: ServicePartKind
    /// 0-based position among the new parts: sermon, then Bible class, then songs in their old order.
    var order: Int
    var title: String
    var person: String
    var isFavourite: Bool
    var songType: SongType
    var hymnNumber: String
}

enum ServicePartMigration {
    /// The parts to create for an old-layout service. A sermon or class is created when anything was typed,
    /// noted, attached, commented or starred. Blank songs are skipped. Songs with a number become hymns; songs
    /// without one become choruses (the old layout had no type).
    static func plan(_ input: LegacyServiceInput) -> [PlannedServicePart] {
        var result: [PlannedServicePart] = []

        let sermon = ServicesLogic.sectionHasContent(
            texts: [input.sermonTitle, input.sermonist],
            hasNote: input.sermonHasNote,
            verseCount: input.sermonVerseCount
        ) || input.sermonFavourite || input.sermonCommentCount > 0
        if sermon {
            result.append(PlannedServicePart(
                source: .sermon, kind: .sermon, order: result.count,
                title: input.sermonTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                person: input.sermonist.trimmingCharacters(in: .whitespacesAndNewlines),
                isFavourite: input.sermonFavourite, songType: .hymn, hymnNumber: ""
            ))
        }

        let bibleClass = ServicesLogic.sectionHasContent(
            texts: [input.classLesson, input.classTeacher],
            hasNote: input.classHasNote,
            verseCount: input.classVerseCount
        ) || input.classFavourite || input.classCommentCount > 0
        if bibleClass {
            result.append(PlannedServicePart(
                source: .bibleClass, kind: .bibleClass, order: result.count,
                title: input.classLesson.trimmingCharacters(in: .whitespacesAndNewlines),
                person: input.classTeacher.trimmingCharacters(in: .whitespacesAndNewlines),
                isFavourite: input.classFavourite, songType: .hymn, hymnNumber: ""
            ))
        }

        let songs = input.songs.enumerated().sorted { lhs, rhs in
            if lhs.element.order != rhs.element.order { return lhs.element.order < rhs.element.order }
            return lhs.offset < rhs.offset
        }
        for (index, song) in songs {
            let number = song.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = song.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if number.isEmpty && title.isEmpty { continue }
            result.append(PlannedServicePart(
                source: .song(index), kind: .song, order: result.count,
                title: title, person: "", isFavourite: false,
                songType: number.isEmpty ? .chorus : .hymn, hymnNumber: number
            ))
        }
        return result
    }
}

// MARK: - Applying to the store

extension ServicePartMigration {
    /// Migrates every service not yet looked at. Does not save; the caller saves (or rolls back).
    /// Returns how many services got new parts.
    @MainActor
    @discardableResult
    static func migrateAll(in context: ModelContext) -> Int {
        let services = (try? context.fetch(FetchDescriptor<Service>())) ?? []
        let pending = services.filter { !$0.partsMigrated }
        guard !pending.isEmpty else { return 0 }
        var library = SongLibrary.allSongs(in: context)
        var changed = 0
        for service in pending {
            if migrate(service, in: context, library: &library) {
                changed += 1
            }
        }
        return changed
    }

    /// Launch hook: migrate and save. Safe to call every launch.
    @MainActor
    static func runOnLaunch(in context: ModelContext) {
        if migrateAll(in: context) > 0 || context.hasChanges {
            try? context.save()
        }
    }

    /// Moves one service's legacy content into parts. Returns true when parts were created.
    @MainActor
    @discardableResult
    static func migrate(_ service: Service, in context: ModelContext, library: inout [LibrarySong]) -> Bool {
        guard !service.partsMigrated else { return false }
        defer { service.partsMigrated = true }

        // Only content not already owned by a part counts as legacy.
        let verses = service.verses.filter { $0.servicePart == nil }
        let comments = service.comments.filter { $0.servicePart == nil }
        let songs = service.songs.sorted { $0.order < $1.order }

        let sermonVerses = verses.filter { $0.part != .bibleClass }
        let classVerses = verses.filter { $0.part == .bibleClass }
        let sermonComments = comments.filter { $0.field != .bibleClass }
        let classComments = comments.filter { $0.field == .bibleClass }

        let input = LegacyServiceInput(
            sermonTitle: service.sermonTitle,
            sermonist: service.sermonist,
            sermonHasNote: !service.sermonNote.characters.isEmpty,
            sermonFavourite: service.sermonFavourite,
            sermonVerseCount: sermonVerses.count,
            sermonCommentCount: sermonComments.count,
            classLesson: service.classLesson,
            classTeacher: service.classTeacher,
            classHasNote: !service.classNote.characters.isEmpty,
            classFavourite: service.classFavourite,
            classVerseCount: classVerses.count,
            classCommentCount: classComments.count,
            songs: songs.map { LegacyServiceInput.SongInput(hymnNumber: $0.hymnNumber, title: $0.title, order: $0.order) }
        )
        let planned = plan(input)
        guard !planned.isEmpty else { return false }

        let base = service.nextPartOrder
        for item in planned {
            let part = ServicePart(
                kind: item.kind,
                order: base + item.order,
                title: item.title,
                person: item.person,
                isFavourite: item.isFavourite,
                songType: item.songType,
                hymnNumber: item.hymnNumber,
                createdAt: service.date
            )
            context.insert(part)
            part.service = service

            switch item.source {
            case .sermon:
                part.notesData = service.sermonNoteData
                move(sermonVerses, comments: sermonComments, to: part)
            case .bibleClass:
                part.notesData = service.classNoteData
                move(classVerses, comments: classComments, to: part)
            case .song:
                let key = SongKey(title: part.title, type: part.songType, hymnNumber: part.hymnNumber)
                if let index = SongLibraryLogic.matchIndex(for: key, in: library.map { $0.key }) {
                    part.librarySong = library[index]
                } else if !part.title.isEmpty {
                    let song = LibrarySong(
                        title: part.title,
                        songType: part.songType,
                        hymnNumber: part.hymnNumber,
                        source: .logged
                    )
                    context.insert(song)
                    library.append(song)
                    part.librarySong = song
                }
                if let song = part.librarySong {
                    let date = service.date
                    if song.lastSungAt.map({ $0 < date }) ?? true { song.lastSungAt = date }
                }
            }
        }
        return true
    }

    @MainActor
    private static func move(_ verses: [VerseRef], comments: [NoteComment], to part: ServicePart) {
        for verse in verses {
            verse.service = nil
            verse.servicePart = part
        }
        for comment in comments {
            comment.service = nil
            comment.field = .body
            comment.servicePart = part
        }
    }
}

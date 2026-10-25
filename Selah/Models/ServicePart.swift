import Foundation
import SwiftData

/// One part of a service, in the order it happened: a sermon, a Bible class or a song.
///
/// Sermons and Bible classes use `title` (sermon title or lesson), `person` (sermonist or "Taught by"),
/// verses and rich notes. Songs use `title`, `songType` and, for hymns, `hymnNumber`, and link to the song library.
@Model
final class ServicePart {
    var kind: ServicePartKind = ServicePartKind.sermon
    var order: Int = 0
    /// Sermon title, Bible class lesson or song title.
    var title: String = ""
    /// Sermonist or "Taught by". Not used for songs.
    var person: String = ""
    /// Rich notes, encoded with `RichTextCoding`.
    var notesData: Data = Data()
    var isFavourite: Bool = false
    var createdAt: Date = Date()

    // Songs only.
    var songType: SongType = SongType.hymn
    /// Only meaningful for hymns.
    var hymnNumber: String = ""

    var service: Service?
    /// The song library entry this song is linked to (songs only). Deleting the library song leaves the part.
    var librarySong: LibrarySong?

    @Relationship(deleteRule: .cascade, inverse: \VerseRef.servicePart)
    var verses: [VerseRef] = []

    @Relationship(deleteRule: .cascade, inverse: \NoteComment.servicePart)
    var comments: [NoteComment] = []

    var notes: AttributedString {
        get { RichTextCoding.decode(notesData) }
        set { notesData = RichTextCoding.encode(newValue) }
    }

    init(
        kind: ServicePartKind = .sermon,
        order: Int = 0,
        title: String = "",
        person: String = "",
        notes: AttributedString = AttributedString(),
        isFavourite: Bool = false,
        songType: SongType = .hymn,
        hymnNumber: String = "",
        createdAt: Date = Date()
    ) {
        self.kind = kind
        self.order = order
        self.title = title
        self.person = person
        self.notesData = notes.characters.isEmpty ? Data() : RichTextCoding.encode(notes)
        self.isFavourite = isFavourite
        self.songType = songType
        self.hymnNumber = hymnNumber
        self.createdAt = createdAt
    }

    /// True when the notes hold any text.
    var hasNotes: Bool {
        !notesData.isEmpty && !notes.characters.isEmpty
    }

    /// True when anything was typed or attached (a part with nothing in it can be deleted without asking).
    var hasContent: Bool {
        ServicesLogic.sectionHasContent(
            texts: [title, person, kind == .song ? hymnNumber : ""],
            hasNote: hasNotes,
            verseCount: verses.count
        )
    }

    /// Plain value copy for the pure rules in `ServicesLogic`.
    var summary: ServicePartSummary {
        ServicePartSummary(
            kind: kind,
            title: title,
            person: person,
            songType: songType,
            hymnNumber: hymnNumber,
            isFavourite: isFavourite
        )
    }
}

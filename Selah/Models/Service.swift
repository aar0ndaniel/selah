import Foundation
import SwiftData

/// One recorded gathering. Its content is `parts`: sermons, Bible classes and songs in the order they happened.
///
/// The sermon/class fields, `verses` and `songs` are the pre-parts layout. They stay in the schema so old stores and
/// backups still load, but the app no longer writes them: `ServicePartMigration` copies them into parts once
/// (`partsMigrated`), and everything else reads `parts`.
@Model
final class Service {
    var date: Date = Date()
    var gatheringName: String = ""

    // MARK: Legacy layout (read only by ServicePartMigration and BackupService)
    var sermonTitle: String = ""
    var sermonist: String = ""
    var sermonNoteData: Data = Data()
    var sermonFavourite: Bool = false
    var classLesson: String = ""
    var classTeacher: String = ""
    var classNoteData: Data = Data()
    var classFavourite: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \VerseRef.service)
    var verses: [VerseRef] = []

    @Relationship(deleteRule: .cascade, inverse: \Song.service)
    var songs: [Song] = []

    @Relationship(deleteRule: .cascade, inverse: \NoteComment.service)
    var comments: [NoteComment] = []

    // MARK: Parts

    /// Sermons, Bible classes and songs. Use `orderedParts` for display.
    @Relationship(deleteRule: .cascade, inverse: \ServicePart.service)
    var parts: [ServicePart] = []

    /// True once `ServicePartMigration` has looked at this service (and copied any legacy content into parts).
    var partsMigrated: Bool = false

    var sermonNote: AttributedString {
        get { RichTextCoding.decode(sermonNoteData) }
        set { sermonNoteData = RichTextCoding.encode(newValue) }
    }

    var classNote: AttributedString {
        get { RichTextCoding.decode(classNoteData) }
        set { classNoteData = RichTextCoding.encode(newValue) }
    }

    init(
        date: Date = Date(),
        gatheringName: String = "",
        sermonTitle: String = "",
        sermonist: String = "",
        sermonNote: AttributedString = AttributedString(),
        sermonFavourite: Bool = false,
        classLesson: String = "",
        classTeacher: String = "",
        classNote: AttributedString = AttributedString(),
        classFavourite: Bool = false
    ) {
        self.date = date
        self.gatheringName = gatheringName
        self.sermonTitle = sermonTitle
        self.sermonist = sermonist
        self.sermonNoteData = RichTextCoding.encode(sermonNote)
        self.sermonFavourite = sermonFavourite
        self.classLesson = classLesson
        self.classTeacher = classTeacher
        self.classNoteData = RichTextCoding.encode(classNote)
        self.classFavourite = classFavourite
    }

    // MARK: Reading parts

    /// Parts in the order they happened.
    var orderedParts: [ServicePart] {
        parts.sorted { lhs, rhs in
            if lhs.order != rhs.order { return lhs.order < rhs.order }
            return lhs.createdAt < rhs.createdAt
        }
    }

    func orderedParts(of kind: ServicePartKind) -> [ServicePart] {
        orderedParts.filter { $0.kind == kind }
    }

    /// Next free `order` value for a new part.
    var nextPartOrder: Int {
        (parts.map { $0.order }.max() ?? -1) + 1
    }

    var hasBibleClass: Bool { parts.contains { $0.kind == .bibleClass } }

    var hasFavouritePart: Bool { parts.contains { $0.isFavourite } }

    /// The first non-empty part notes, for note cards (highlights show there). Empty when no part has notes.
    var previewNote: AttributedString {
        orderedParts.first { $0.hasNotes }?.notes ?? AttributedString()
    }
}

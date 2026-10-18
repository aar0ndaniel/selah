import Foundation
import SwiftData

@Model
final class Service {
    var date: Date = Date()
    var gatheringName: String = ""
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
}

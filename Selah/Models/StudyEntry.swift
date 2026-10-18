import Foundation
import SwiftData

@Model
final class StudyEntry {
    var date: Date = Date()
    var chapter: Int = 1
    var noteData: Data = Data()
    var createdAt: Date = Date()

    var plan: ReadingPlan?

    @Relationship(deleteRule: .cascade, inverse: \VerseRef.studyEntry)
    var bestVerse: VerseRef?

    @Relationship(deleteRule: .cascade, inverse: \NoteComment.studyEntry)
    var comments: [NoteComment] = []

    /// "What I learnt" as rich text.
    var note: AttributedString {
        get { RichTextCoding.decode(noteData) }
        set { noteData = RichTextCoding.encode(newValue) }
    }

    init(
        date: Date = Date(),
        chapter: Int = 1,
        note: AttributedString = AttributedString(),
        createdAt: Date = Date()
    ) {
        self.date = date
        self.chapter = chapter
        self.noteData = RichTextCoding.encode(note)
        self.createdAt = createdAt
    }
}

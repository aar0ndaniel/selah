import Foundation
import SwiftData

@Model
final class PersonalNote {
    var title: String = ""
    var bodyData: Data = Data()
    var colour: NoteColour = NoteColour.mint
    var pinned: Bool = false
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \VerseRef.personalNote)
    var verses: [VerseRef] = []

    @Relationship(deleteRule: .cascade, inverse: \NoteComment.personalNote)
    var comments: [NoteComment] = []

    var body: AttributedString {
        get { RichTextCoding.decode(bodyData) }
        set { bodyData = RichTextCoding.encode(newValue) }
    }

    init(
        title: String = "",
        body: AttributedString = AttributedString(),
        colour: NoteColour = .mint,
        pinned: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.bodyData = RichTextCoding.encode(body)
        self.colour = colour
        self.pinned = pinned
        self.updatedAt = updatedAt
    }
}

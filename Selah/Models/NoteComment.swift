import Foundation
import SwiftData

@Model
final class NoteComment {
    var highlightID: String = UUID().uuidString
    var quotedText: String = ""
    var comment: String = ""
    var createdAt: Date = Date()
    var field: CommentField = CommentField.body

    var studyEntry: StudyEntry?
    var service: Service?
    var personalNote: PersonalNote?
    /// The sermon or Bible class part whose notes this comment belongs to.
    var servicePart: ServicePart?

    init(
        highlightID: String = UUID().uuidString,
        quotedText: String = "",
        comment: String = "",
        createdAt: Date = Date(),
        field: CommentField = .body
    ) {
        self.highlightID = highlightID
        self.quotedText = quotedText
        self.comment = comment
        self.createdAt = createdAt
        self.field = field
    }
}

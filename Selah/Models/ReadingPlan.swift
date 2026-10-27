import Foundation
import SwiftData

@Model
final class ReadingPlan {
    var bookName: String = ""
    var totalChapters: Int = 1
    var status: ReadingStatus = ReadingStatus.upNext
    var plannedDays: Int = 7
    var startDate: Date?
    var finishedDate: Date?
    var chaptersRead: [Int] = []
    /// Optional banner photo for the book page (JPEG, at most 1600 px wide). Kept outside the main store.
    @Attribute(.externalStorage) var bannerData: Data? = nil
    /// Card colour, stored as a `NoteColour` raw value.
    var toneRaw: String = "sage"
    /// The study's own name, for example "Calling of Mankind". Empty means the book name is used.
    var title: String = ""
    /// A short description shown under the title on the book page.
    var summary: String = ""
    /// A built-in illustration for the Study card (`StudyIllustration` raw value). Empty means none; a banner photo
    /// wins over it.
    var illustrationRaw: String = ""

    @Relationship(deleteRule: .cascade, inverse: \StudyEntry.plan)
    var entries: [StudyEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \ReadingReminder.plan)
    var reminders: [ReadingReminder] = []

    init(
        bookName: String = "",
        totalChapters: Int = 1,
        status: ReadingStatus = .upNext,
        plannedDays: Int = 7,
        startDate: Date? = nil,
        finishedDate: Date? = nil,
        chaptersRead: [Int] = []
    ) {
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.status = status
        self.plannedDays = plannedDays
        self.startDate = startDate
        self.finishedDate = finishedDate
        self.chaptersRead = chaptersRead
    }

    /// The card colour as a `NoteColour` (so the same swatches serve notes and books).
    var tone: NoteColour {
        get { NoteColour(rawValue: toneRaw) ?? .sage }
        set { toneRaw = newValue.rawValue }
    }

    /// The design-system tone to draw this book's card with.
    var cardTone: Tone { tone.tone }

    /// The study title, or the book name when no title is set.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? bookName : trimmed
    }
}

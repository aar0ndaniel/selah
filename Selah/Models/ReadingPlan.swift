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
}

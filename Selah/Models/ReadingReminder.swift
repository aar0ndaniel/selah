import Foundation
import SwiftData

@Model
final class ReadingReminder {
    var hour: Int = 7
    var minute: Int = 0
    var notificationID: String = UUID().uuidString
    var plan: ReadingPlan?

    init(hour: Int = 7, minute: Int = 0, notificationID: String = UUID().uuidString) {
        self.hour = hour
        self.minute = minute
        self.notificationID = notificationID
    }
}

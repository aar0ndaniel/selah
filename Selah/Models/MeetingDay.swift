import Foundation
import SwiftData

@Model
final class MeetingDay {
    /// 1 = Sunday ... 7 = Saturday (Calendar weekday).
    var weekday: Int = 1
    var hour: Int = 9
    var minute: Int = 0
    var name: String = ""
    var reminderMinutesBefore: Int = 60
    var isActive: Bool = true

    init(
        weekday: Int = 1,
        hour: Int = 9,
        minute: Int = 0,
        name: String = "",
        reminderMinutesBefore: Int = 60,
        isActive: Bool = true
    ) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.name = name
        self.reminderMinutesBefore = reminderMinutesBefore
        self.isActive = isActive
    }
}

import Foundation

/// The reminder defaults chosen in Settings. Settings writes them with `@AppStorage`;
/// this reads the same keys so new books and new meeting days start from them.
enum ReminderDefaults {
    static let readingKey = "defaultReadingMinutes"
    static let serviceKey = "defaultServiceReminderMinutes"
    static let fallbackReadingMinutes = 7 * 60
    static let fallbackServiceMinutes = 60

    /// Minutes after midnight for the daily reading reminder.
    static var readingMinutes: Int {
        UserDefaults.standard.object(forKey: readingKey) as? Int ?? fallbackReadingMinutes
    }

    /// Minutes before a gathering to remind.
    static var serviceMinutes: Int {
        UserDefaults.standard.object(forKey: serviceKey) as? Int ?? fallbackServiceMinutes
    }

    /// `now` at the default reading time, for time pickers.
    static func readingTime(calendar: Calendar = .current, now: Date = Date()) -> Date {
        let minutes = readingMinutes
        return calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now) ?? now
    }
}

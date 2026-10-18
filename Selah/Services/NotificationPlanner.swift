import Foundation

/// Value snapshot of a reading plan, safe to pass anywhere.
struct PlanSnapshot: Sendable, Equatable {
    var id: String
    var bookName: String
    var status: ReadingStatus
    var chaptersRead: [Int]
    var totalChapters: Int
    var reminders: [ReminderTime]
}

struct ReminderTime: Sendable, Equatable {
    var hour: Int
    var minute: Int
}

/// Value snapshot of a meeting day.
struct MeetingSnapshot: Sendable, Equatable {
    var id: String
    /// 1 = Sunday ... 7 = Saturday.
    var weekday: Int
    var hour: Int
    var minute: Int
    var name: String
    var reminderMinutesBefore: Int?
    var isActive: Bool
}

struct PlannedNotification: Sendable, Equatable {
    var identifier: String
    var title: String
    var body: String
    var trigger: DateComponents
    var repeats: Bool
}

/// Pure rules for which local notifications should exist.
enum NotificationPlanner {
    static let readingPrefix = "reading-"
    static let meetingPrefix = "meeting-"

    static func plan(plans: [PlanSnapshot], meetings: [MeetingSnapshot]) -> [PlannedNotification] {
        var result: [PlannedNotification] = []
        var seen = Set<String>()

        for plan in plans where plan.status == .reading {
            let chapter = nextUnreadChapter(chaptersRead: plan.chaptersRead, totalChapters: plan.totalChapters)
            for time in plan.reminders {
                let identifier = readingIdentifier(planID: plan.id, hour: time.hour, minute: time.minute)
                guard seen.insert(identifier).inserted else { continue }
                result.append(PlannedNotification(
                    identifier: identifier,
                    title: "Reading",
                    body: "Time for \(plan.bookName) \(chapter)",
                    trigger: DateComponents(hour: time.hour, minute: time.minute),
                    repeats: true
                ))
            }
        }

        for day in meetings where day.isActive {
            guard let before = day.reminderMinutesBefore, before > 0 else { continue }
            let identifier = meetingIdentifier(dayID: day.id)
            guard seen.insert(identifier).inserted else { continue }
            let moved = shifted(weekday: day.weekday, hour: day.hour, minute: day.minute, minutesEarlier: before)
            let name = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = name.isEmpty ? "Meeting" : name
            result.append(PlannedNotification(
                identifier: identifier,
                title: "\(label) at \(timeText(hour: day.hour, minute: day.minute))",
                body: "Your notes page is ready.",
                trigger: DateComponents(hour: moved.hour, minute: moved.minute, weekday: moved.weekday),
                repeats: true
            ))
        }
        return result
    }

    static func readingIdentifier(planID: String, hour: Int, minute: Int) -> String {
        readingPrefix + planID + "-" + twoDigits(hour) + twoDigits(minute)
    }

    static func meetingIdentifier(dayID: String) -> String {
        meetingPrefix + dayID
    }

    /// First chapter not read, or the last chapter when all are read.
    static func nextUnreadChapter(chaptersRead: [Int], totalChapters: Int) -> Int {
        let last = max(totalChapters, 1)
        return (1...last).first { !chaptersRead.contains($0) } ?? last
    }

    /// Moves a weekly time earlier by some minutes, wrapping across midnight and the week.
    static func shifted(weekday: Int, hour: Int, minute: Int, minutesEarlier: Int) -> (weekday: Int, hour: Int, minute: Int) {
        let week = 7 * 24 * 60
        let day = ((weekday - 1) % 7 + 7) % 7
        let total = day * 1440 + hour * 60 + minute - minutesEarlier
        let wrapped = ((total % week) + week) % week
        return (wrapped / 1440 + 1, (wrapped % 1440) / 60, wrapped % 60)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func timeText(hour: Int, minute: Int) -> String {
        twoDigits(hour) + ":" + twoDigits(minute)
    }
}

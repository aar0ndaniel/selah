import Foundation

/// One weekly meeting as plain values (no SwiftData), so the rules are unit-testable.
struct MeetingSlot: Equatable, Sendable {
    var name: String
    /// 1 = Sunday ... 7 = Saturday (Calendar weekday).
    var weekday: Int
    var hour: Int
    var minute: Int
    var isActive: Bool = true
}

struct NextGathering: Equatable, Sendable {
    var name: String
    var date: Date
    var isToday: Bool
    /// For example "Tonight 18:30", "Tomorrow 09:00" or "Sunday 09:00".
    var text: String
}

/// A reading plan as plain values.
struct ReadingSnapshot: Equatable, Sendable {
    var bookName: String
    var status: ReadingStatus
    var chaptersRead: [Int]
    var totalChapters: Int
    var plannedDays: Int
    var startDate: Date?
}

struct ReadingItem: Equatable, Sendable {
    var bookName: String
    var nextChapter: Int
    var allRead: Bool
    var dayNumber: Int
    var plannedDays: Int
    var chaptersPerDay: Int
    var hasEntryToday: Bool

    /// "Day 3 of 14"
    var dayText: String { "Day \(dayNumber) of \(plannedDays)" }

    /// "1 chapter a day"
    var paceText: String {
        if allRead { return "All chapters read" }
        return chaptersPerDay == 1 ? "1 chapter a day" : "\(chaptersPerDay) chapters a day"
    }

    /// "Next: chapter 3"
    var nextText: String {
        allRead ? "All chapters read" : "Next: chapter \(nextChapter)"
    }
}

enum TodaySummary {
    /// The soonest active meeting at or after `now`: later today, or the next day it falls on.
    static func nextGathering(
        from slots: [MeetingSlot],
        now: Date,
        calendar: Calendar = .current
    ) -> NextGathering? {
        let startOfToday = calendar.startOfDay(for: now)
        var best: NextGathering?

        for slot in slots where slot.isActive && (1...7).contains(slot.weekday) {
            for offset in 0...7 {
                guard
                    let day = calendar.date(byAdding: .day, value: offset, to: startOfToday),
                    calendar.component(.weekday, from: day) == slot.weekday,
                    let date = calendar.date(bySettingHour: slot.hour, minute: slot.minute, second: 0, of: day),
                    date >= now
                else { continue }

                let isEarlier = best.map { date < $0.date } ?? true
                if isEarlier {
                    best = NextGathering(
                        name: displayName(for: slot, calendar: calendar),
                        date: date,
                        isToday: offset == 0,
                        text: whenText(offset: offset, slot: slot, calendar: calendar)
                    )
                }
                break
            }
        }
        return best
    }

    private static func displayName(for slot: MeetingSlot, calendar: Calendar) -> String {
        let trimmed = slot.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return weekdayName(slot.weekday, calendar: calendar)
    }

    private static func weekdayName(_ weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }

    private static func whenText(offset: Int, slot: MeetingSlot, calendar: Calendar) -> String {
        let time = String(format: "%02d:%02d", slot.hour, slot.minute)
        switch offset {
        case 0: return (slot.hour >= 17 ? "Tonight " : "Today ") + time
        case 1: return "Tomorrow " + time
        default: return weekdayName(slot.weekday, calendar: calendar) + " " + time
        }
    }

    /// True when any of the dates falls on the same day as `now`.
    static func hasEntry(on now: Date, dates: [Date], calendar: Calendar = .current) -> Bool {
        dates.contains { calendar.isDate($0, inSameDayAs: now) }
    }

    /// Reading item for a plan that is in Reading status; nil for any other status.
    static func readingItem(
        for plan: ReadingSnapshot,
        hasEntryToday: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> ReadingItem? {
        guard plan.status == .reading else { return nil }
        let last = max(plan.totalChapters, 1)
        let next = (1...last).first { !plan.chaptersRead.contains($0) }
        let pace = ReadingProgress.pace(
            remainingChapters: plan.totalChapters - plan.chaptersRead.count,
            plannedDays: plan.plannedDays,
            daysElapsed: ReadingProgress.daysElapsed(from: plan.startDate, to: now, calendar: calendar)
        )
        return ReadingItem(
            bookName: plan.bookName,
            nextChapter: next ?? last,
            allRead: next == nil,
            dayNumber: pace.dayNumber,
            plannedDays: pace.plannedDays,
            chaptersPerDay: pace.chaptersPerDay,
            hasEntryToday: hasEntryToday
        )
    }
}

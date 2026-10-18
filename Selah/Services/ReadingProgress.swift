import Foundation

/// Pure reading-plan rules. No SwiftData here, so everything is unit-testable.
struct ReadingState: Equatable, Sendable {
    var status: ReadingStatus
    var chaptersRead: [Int]
    var totalChapters: Int
    var startDate: Date?
    var finishedDate: Date?

    /// Marks or unmarks one chapter and applies the status rules.
    mutating func setChapter(_ chapter: Int, read: Bool, now: Date = Date()) {
        guard chapter >= 1, chapter <= totalChapters else { return }

        if read {
            if !chaptersRead.contains(chapter) {
                chaptersRead.append(chapter)
                chaptersRead.sort()
            }
        } else {
            chaptersRead.removeAll { $0 == chapter }
        }

        let allRead = totalChapters > 0 && chaptersRead.count >= totalChapters

        if read {
            if status == .upNext {
                status = .reading
                if startDate == nil { startDate = now }
            }
            if allRead {
                status = .done
                finishedDate = now
            }
        } else if status == .done {
            status = .reading
            finishedDate = nil
        }
    }
}

struct ReadingPace: Equatable, Sendable {
    var chaptersPerDay: Int
    var remainingDays: Int
    var dayNumber: Int
    var plannedDays: Int
}

enum ReadingProgress {
    /// chaptersPerDay = ceil(remainingChapters / remainingDays), at least 1.
    /// remainingDays = plannedDays - daysElapsed, at least 1.
    static func pace(remainingChapters: Int, plannedDays: Int, daysElapsed: Int) -> ReadingPace {
        let remainingDays = max(plannedDays - daysElapsed, 1)
        let remaining = max(remainingChapters, 0)
        let perDay = max((remaining + remainingDays - 1) / remainingDays, 1)
        return ReadingPace(
            chaptersPerDay: perDay,
            remainingDays: remainingDays,
            dayNumber: dayNumber(plannedDays: plannedDays, daysElapsed: daysElapsed),
            plannedDays: max(plannedDays, 1)
        )
    }

    /// "Day X of N": X is clamped between 1 and N.
    static func dayNumber(plannedDays: Int, daysElapsed: Int) -> Int {
        let total = max(plannedDays, 1)
        return min(max(daysElapsed + 1, 1), total)
    }

    /// Whole days between the start date and now. Zero when not started.
    static func daysElapsed(from start: Date?, to now: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let start else { return 0 }
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: now)
        return max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 0)
    }
}

extension ReadingPlan {
    var state: ReadingState {
        ReadingState(
            status: status,
            chaptersRead: chaptersRead,
            totalChapters: totalChapters,
            startDate: startDate,
            finishedDate: finishedDate
        )
    }

    /// Marks or unmarks a chapter and updates status and dates.
    func setChapter(_ chapter: Int, read: Bool, now: Date = Date()) {
        var next = state
        next.setChapter(chapter, read: read, now: now)
        chaptersRead = next.chaptersRead
        status = next.status
        startDate = next.startDate
        finishedDate = next.finishedDate
    }

    func pace(now: Date = Date(), calendar: Calendar = .current) -> ReadingPace {
        ReadingProgress.pace(
            remainingChapters: totalChapters - chaptersRead.count,
            plannedDays: plannedDays,
            daysElapsed: ReadingProgress.daysElapsed(from: startDate, to: now, calendar: calendar)
        )
    }
}

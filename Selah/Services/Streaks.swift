import Foundation

// Streak rules. Pure value types and functions, no SwiftData, so everything is unit-testable.
//
// Definitions (all days are calendar days in the given calendar):
// - Study streak: consecutive days with at least one study entry. Today not done yet does not break it.
// - Service streak: consecutive scheduled meetings (active meeting weekdays) that have a service recorded that day.
//   Days that are not meeting days are skipped. A meeting today that is not recorded yet does not break it.
// - Overall streak: consecutive days on which everything that was due was done. A study entry is due on days a
//   Reading plan was active; a service is due on meeting days. Days with nothing due are skipped (they neither
//   extend nor break the streak). Today with something still open does not break it.
// - Best: the longest run found by the same rules over all the data.
// - Freezes (owner, 6 Nov): everyone gets 5 a calendar month. A missed day while a streak is running uses one of that
//   month's freezes: the streak holds (the frozen day doesn't add to it) and carries on when the user comes back.
//   With no freezes left that month, a missed day resets the streak to 0. A miss while the streak is already 0 uses
//   none. Each kind (study, service, overall) keeps its own count.

/// The span of days a Reading plan counted as active. `end` nil means still reading.
struct ReadingSpan: Equatable, Sendable {
    var start: Date
    var end: Date?
}

struct StreakInput: Equatable, Sendable {
    /// One date per study entry (duplicates are fine).
    var studyDates: [Date] = []
    /// One date per recorded service.
    var serviceDates: [Date] = []
    /// Weekdays (1 = Sunday ... 7 = Saturday) of active meeting days.
    var meetingWeekdays: Set<Int> = []
    var readingSpans: [ReadingSpan] = []

    init(
        studyDates: [Date] = [],
        serviceDates: [Date] = [],
        meetingWeekdays: Set<Int> = [],
        readingSpans: [ReadingSpan] = []
    ) {
        self.studyDates = studyDates
        self.serviceDates = serviceDates
        self.meetingWeekdays = meetingWeekdays
        self.readingSpans = readingSpans
    }
}

struct StreakCount: Equatable, Sendable {
    var current: Int = 0
    var best: Int = 0
    var doneToday: Bool = false
    /// Freezes still unused in today's month.
    var freezesLeft: Int = Streaks.freezesPerMonth
    /// Missed days a freeze covered (start of day).
    var frozenDays: Set<Date> = []
}

struct StreakSummary: Equatable, Sendable {
    var study = StreakCount()
    var service = StreakCount()
    var overall = StreakCount()
}

enum WeekDayState: Equatable, Sendable {
    /// Something was due and it is all done.
    case done
    /// Today, something is due and not finished yet.
    case pending
    /// A past day with something due that was not finished.
    case missed
    /// A missed day covered by a streak freeze: the streak held.
    case frozen
    /// Nothing due, or a day still to come.
    case none
}

struct WeekDay: Equatable, Sendable {
    var date: Date
    var isToday: Bool
    var state: WeekDayState
    var studyCount: Int
}

enum Streaks {
    /// Longest look-back, so the loop stays cheap for very old stores.
    static let maxLookbackDays = 800
    /// Streak freezes each calendar month.
    static let freezesPerMonth = 5

    private enum DayResult {
        case done, missed, skip
    }

    // MARK: Summary

    static func summary(_ input: StreakInput, today: Date, calendar: Calendar = .current) -> StreakSummary {
        let context = Context(input, today: today, calendar: calendar)
        guard let first = context.firstDay else { return StreakSummary() }

        let study = pass(from: first, to: context.today, calendar: calendar, rule: context.studyRule)
        let service = pass(from: first, to: context.today, calendar: calendar, rule: context.serviceRule)
        let overall = pass(from: first, to: context.today, calendar: calendar, rule: context.overallRule)

        return StreakSummary(
            study: StreakCount(
                current: study.current,
                best: study.best,
                doneToday: context.studyDays.contains(context.today),
                freezesLeft: study.freezesLeft,
                frozenDays: study.frozen
            ),
            service: StreakCount(
                current: service.current,
                best: service.best,
                doneToday: context.serviceDays.contains(context.today),
                freezesLeft: service.freezesLeft,
                frozenDays: service.frozen
            ),
            overall: StreakCount(
                current: overall.current,
                best: overall.best,
                doneToday: context.overallRule(context.today) == .done,
                freezesLeft: overall.freezesLeft,
                frozenDays: overall.frozen
            )
        )
    }

    // MARK: Week

    /// Monday to Sunday of the week that contains `today`.
    static func week(_ input: StreakInput, today: Date, calendar: Calendar = .current) -> [WeekDay] {
        let context = Context(input, today: today, calendar: calendar)
        let weekday = calendar.component(.weekday, from: context.today)
        let sinceMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: context.today) else { return [] }

        let frozen = summary(input, today: today, calendar: calendar).overall.frozenDays
        var counts: [Date: Int] = [:]
        for date in input.studyDates {
            counts[calendar.startOfDay(for: date), default: 0] += 1
        }

        var days: [WeekDay] = []
        for offset in 0..<7 {
            guard let raw = calendar.date(byAdding: .day, value: offset, to: monday) else { continue }
            let day = calendar.startOfDay(for: raw)
            let isToday = day == context.today
            let state: WeekDayState
            if day > context.today {
                state = .none
            } else {
                switch context.overallRule(day) {
                case .done: state = .done
                case .missed: state = isToday ? .pending : (frozen.contains(day) ? .frozen : .missed)
                case .skip: state = .none
                }
            }
            days.append(WeekDay(date: day, isToday: isToday, state: state, studyCount: counts[day] ?? 0))
        }
        return days
    }

    // MARK: Forward pass

    private struct PassResult {
        var current: Int
        var best: Int
        var frozen: Set<Date>
        var freezesLeft: Int
    }

    /// Walks from `start` to today. A missed day (not today, which is still open) uses one of that month's freezes
    /// while a streak is running; with none left, it resets the run.
    private static func pass(
        from start: Date,
        to today: Date,
        calendar: Calendar,
        rule: (Date) -> DayResult
    ) -> PassResult {
        var run = 0
        var best = 0
        var frozen: Set<Date> = []
        var usedByMonth: [Int: Int] = [:]
        var day = start
        while day <= today {
            switch rule(day) {
            case .done:
                run += 1
                best = max(best, run)
            case .missed:
                guard day != today else { break }
                let month = monthKey(day, calendar: calendar)
                if run > 0, usedByMonth[month, default: 0] < freezesPerMonth {
                    usedByMonth[month, default: 0] += 1
                    frozen.insert(day)
                } else {
                    run = 0
                }
            case .skip:
                break
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = calendar.startOfDay(for: next)
        }
        let left = freezesPerMonth - usedByMonth[monthKey(today, calendar: calendar), default: 0]
        return PassResult(current: run, best: best, frozen: frozen, freezesLeft: left)
    }

    private static func monthKey(_ day: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month], from: day)
        return (parts.year ?? 0) * 100 + (parts.month ?? 0)
    }

    // MARK: Context

    private struct Context {
        let calendar: Calendar
        let today: Date
        let studyDays: Set<Date>
        let serviceDays: Set<Date>
        let meetingWeekdays: Set<Int>
        let spans: [(start: Date, end: Date?)]
        let firstDay: Date?

        init(_ input: StreakInput, today rawToday: Date, calendar: Calendar) {
            self.calendar = calendar
            let today = calendar.startOfDay(for: rawToday)
            self.today = today
            studyDays = Set(input.studyDates.map { calendar.startOfDay(for: $0) })
            serviceDays = Set(input.serviceDates.map { calendar.startOfDay(for: $0) })
            meetingWeekdays = input.meetingWeekdays
            spans = input.readingSpans.map {
                (calendar.startOfDay(for: $0.start), $0.end.map { calendar.startOfDay(for: $0) })
            }

            var starts: [Date] = Array(studyDays) + Array(serviceDays) + spans.map { $0.start }
            starts = starts.filter { $0 <= today }
            let earliest = starts.min()
            let limit = calendar.date(byAdding: .day, value: -Streaks.maxLookbackDays, to: today)
            if let earliest {
                firstDay = max(earliest, limit.map { calendar.startOfDay(for: $0) } ?? earliest)
            } else {
                firstDay = nil
            }
        }

        private func isMeetingDay(_ day: Date) -> Bool {
            meetingWeekdays.contains(calendar.component(.weekday, from: day))
        }

        private func isReadingDay(_ day: Date) -> Bool {
            spans.contains { $0.start <= day && ($0.end.map { day <= $0 } ?? true) }
        }

        func studyRule(_ day: Date) -> DayResult {
            studyDays.contains(day) ? .done : .missed
        }

        func serviceRule(_ day: Date) -> DayResult {
            guard isMeetingDay(day) else { return .skip }
            return serviceDays.contains(day) ? .done : .missed
        }

        func overallRule(_ day: Date) -> DayResult {
            let needsStudy = isReadingDay(day)
            let needsService = isMeetingDay(day)
            guard needsStudy || needsService else { return .skip }
            let studyOK = !needsStudy || studyDays.contains(day)
            let serviceOK = !needsService || serviceDays.contains(day)
            return studyOK && serviceOK ? .done : .missed
        }
    }
}

// MARK: - Countdown text

/// "in 2 days" style text for the next-gathering card.
enum GatheringCountdown {
    /// Whole calendar days from `now` to `date` (0 = today).
    static func daysAway(from now: Date, to date: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: now)
        let to = calendar.startOfDay(for: date)
        return max(calendar.dateComponents([.day], from: from, to: to).day ?? 0, 0)
    }

    /// `todayText` is used on the day itself, for example "Tonight 18:30".
    static func text(daysAway: Int, todayText: String) -> String {
        switch daysAway {
        case ...0: return todayText
        case 1: return "Tomorrow"
        default: return "in \(daysAway) days"
        }
    }
}

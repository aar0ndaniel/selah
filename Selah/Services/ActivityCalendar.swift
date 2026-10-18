import Foundation

// Pure logic behind the activity heatmaps and the habit week. Value inputs only (dates and plain structs),
// no SwiftData, so it is all unit-testable. Weeks are Monday-first columns, like GitHub's contribution graph.
//
// - A year is a list of weeks; each week is 7 days Monday to Sunday. Days before 1 Jan and after 31 Dec that pad the
//   first and last week have `isInYear == false` and are not drawn.
// - Level 0...4: 0 none, then 1, 2, 3, 4+ entries in a day. "Binary" sources (services) jump straight to 4.
// - Streak: reuses `Streaks` (study streak rules), so the number always matches the pills on Today.

/// One cell of the heatmap.
struct ActivityDay: Equatable, Sendable, Identifiable {
    var date: Date
    var count: Int
    /// 0...4.
    var level: Int
    /// False for the padding cells before 1 Jan and after 31 Dec.
    var isInYear: Bool
    var isToday: Bool
    var isFuture: Bool

    var id: Date { date }
}

/// A column of the heatmap: Monday to Sunday.
struct ActivityWeek: Equatable, Sendable, Identifiable {
    var start: Date
    var days: [ActivityDay]

    var id: Date { start }
}

/// A month name above the first column that holds that month's 1st.
struct ActivityMonthLabel: Equatable, Sendable, Identifiable {
    var month: Int
    var title: String
    var weekIndex: Int

    var id: Int { month }
}

/// One line of the month-by-month list used at accessibility text sizes.
struct ActivityMonthCount: Equatable, Sendable, Identifiable {
    var month: Int
    var title: String
    var count: Int
    var activeDays: Int

    var id: Int { month }
}

struct ActivityYear: Equatable, Sendable {
    var year: Int
    var weeks: [ActivityWeek]
    var monthLabels: [ActivityMonthLabel]
    var months: [ActivityMonthCount]
    /// Everything counted in the year (entries, or services).
    var total: Int
    /// Days with at least one thing.
    var activeDays: Int
    /// Column that holds today, when today is in this year.
    var currentWeekIndex: Int?
}

/// Week of the habit view: the state of each habit on each of the 7 days (Monday first).
struct HabitWeekStates: Equatable, Sendable {
    var days: [Date]
    var study: [WeekDayState]
    var service: [WeekDayState]
    var overall: [WeekDayState]
    var todayIndex: Int?
}

enum ActivityCalendar {
    // MARK: Counts and levels

    /// Entries per calendar day.
    static func counts(dates: [Date], calendar: Calendar = .current) -> [Date: Int] {
        var result: [Date: Int] = [:]
        for date in dates {
            result[calendar.startOfDay(for: date), default: 0] += 1
        }
        return result
    }

    /// Intensity 0...4. 1, 2, 3 and 4 or more entries; binary sources are either 0 or 4.
    static func level(count: Int, binary: Bool = false) -> Int {
        guard count > 0 else { return 0 }
        return binary ? 4 : min(count, 4)
    }

    // MARK: Weeks

    /// The Monday of the week that holds `date` (start of day).
    static func weekStart(containing date: Date, calendar: Calendar = .current) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let sinceMonday = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -sinceMonday, to: day) ?? day
        return calendar.startOfDay(for: monday)
    }

    private static func addDays(_ days: Int, to date: Date, calendar: Calendar) -> Date {
        calendar.startOfDay(for: calendar.date(byAdding: .day, value: days, to: date) ?? date)
    }

    // MARK: Year

    static func year(
        _ year: Int,
        dates: [Date],
        today: Date,
        binary: Bool = false,
        calendar: Calendar = .current
    ) -> ActivityYear {
        let counts = counts(dates: dates, calendar: calendar)
        let todayDay = calendar.startOfDay(for: today)
        guard
            let jan1 = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
            let dec31 = calendar.date(from: DateComponents(year: year, month: 12, day: 31))
        else {
            return ActivityYear(year: year, weeks: [], monthLabels: [], months: [], total: 0, activeDays: 0, currentWeekIndex: nil)
        }
        let lastDay = calendar.startOfDay(for: dec31)

        var weeks: [ActivityWeek] = []
        var labels: [ActivityMonthLabel] = []
        var monthTotals: [Int: (count: Int, active: Int)] = [:]
        var total = 0
        var activeDays = 0
        var currentWeekIndex: Int?
        let symbols = calendar.shortMonthSymbols

        var start = weekStart(containing: jan1, calendar: calendar)
        while start <= lastDay {
            var days: [ActivityDay] = []
            for offset in 0..<7 {
                let date = addDays(offset, to: start, calendar: calendar)
                let inYear = calendar.component(.year, from: date) == year
                let count = inYear ? (counts[date] ?? 0) : 0
                let month = calendar.component(.month, from: date)
                if inYear {
                    total += count
                    if count > 0 { activeDays += 1 }
                    var entry: (count: Int, active: Int) = monthTotals[month] ?? (count: 0, active: 0)
                    entry.count += count
                    if count > 0 { entry.active += 1 }
                    monthTotals[month] = entry
                    if calendar.component(.day, from: date) == 1 {
                        let title = symbols.indices.contains(month - 1) ? symbols[month - 1] : ""
                        labels.append(ActivityMonthLabel(month: month, title: title, weekIndex: weeks.count))
                    }
                }
                let isToday = date == todayDay
                if isToday && inYear { currentWeekIndex = weeks.count }
                days.append(ActivityDay(
                    date: date,
                    count: count,
                    level: level(count: count, binary: binary),
                    isInYear: inYear,
                    isToday: isToday,
                    isFuture: date > todayDay
                ))
            }
            weeks.append(ActivityWeek(start: start, days: days))
            start = addDays(7, to: start, calendar: calendar)
        }

        let longSymbols = calendar.monthSymbols
        let months: [ActivityMonthCount] = (1...12).map { month in
            let entry: (count: Int, active: Int) = monthTotals[month] ?? (count: 0, active: 0)
            let title = longSymbols.indices.contains(month - 1) ? longSymbols[month - 1] : ""
            return ActivityMonthCount(month: month, title: title, count: entry.count, activeDays: entry.active)
        }

        return ActivityYear(
            year: year,
            weeks: weeks,
            monthLabels: labels,
            months: months,
            total: total,
            activeDays: activeDays,
            currentWeekIndex: currentWeekIndex
        )
    }

    // MARK: Streak

    /// Current study streak, from the same rules as the pills on Today.
    static func studyStreak(dates: [Date], today: Date, calendar: Calendar = .current) -> Int {
        Streaks.summary(StreakInput(studyDates: dates), today: today, calendar: calendar).study.current
    }

    // MARK: Habit week

    /// States for the week that holds `date`. Same rules as `Streaks.week` for the overall row; the study and
    /// service rows follow the same idea for one habit each.
    static func weekStates(
        _ input: StreakInput,
        weekOf date: Date,
        today rawToday: Date,
        calendar: Calendar = .current
    ) -> HabitWeekStates {
        let today = calendar.startOfDay(for: rawToday)
        let start = weekStart(containing: date, calendar: calendar)
        let studyDays = Set(input.studyDates.map { calendar.startOfDay(for: $0) })
        let serviceDays = Set(input.serviceDates.map { calendar.startOfDay(for: $0) })
        let spans = input.readingSpans.map {
            (start: calendar.startOfDay(for: $0.start), end: $0.end.map { calendar.startOfDay(for: $0) })
        }

        var result = HabitWeekStates(days: [], study: [], service: [], overall: [], todayIndex: nil)
        for offset in 0..<7 {
            let day = addDays(offset, to: start, calendar: calendar)
            let studyDue = spans.contains { $0.start <= day && ($0.end.map { day <= $0 } ?? true) }
            let serviceDue = input.meetingWeekdays.contains(calendar.component(.weekday, from: day))
            let studyDone = studyDays.contains(day)
            let serviceDone = serviceDays.contains(day)

            result.days.append(day)
            result.study.append(single(day: day, today: today, due: studyDue, done: studyDone))
            result.service.append(single(day: day, today: today, due: serviceDue, done: serviceDone))

            let anyDue = studyDue || serviceDue
            let allDone = (!studyDue || studyDone) && (!serviceDue || serviceDone)
            result.overall.append(single(day: day, today: today, due: anyDue, done: anyDue && allDone, requireDue: true))
            if day == today { result.todayIndex = offset }
        }
        return result
    }

    private static func single(
        day: Date,
        today: Date,
        due: Bool,
        done: Bool,
        requireDue: Bool = false
    ) -> WeekDayState {
        if day > today { return .none }
        if requireDue && !due { return .none }
        if done { return .done }
        if !due { return .none }
        return day == today ? .pending : .missed
    }

    /// "13 – 19 Oct", or "29 Sep – 5 Oct" when the week crosses a month.
    static func weekRangeLabel(start: Date, calendar: Calendar = .current) -> String {
        let first = calendar.startOfDay(for: start)
        let last = addDays(6, to: first, calendar: calendar)
        let symbols = calendar.shortMonthSymbols
        func month(_ date: Date) -> String {
            let index = calendar.component(.month, from: date) - 1
            return symbols.indices.contains(index) ? symbols[index] : ""
        }
        let firstDay = calendar.component(.day, from: first)
        let lastDay = calendar.component(.day, from: last)
        if calendar.component(.month, from: first) == calendar.component(.month, from: last) {
            return "\(firstDay) \u{2013} \(lastDay) \(month(last))"
        }
        return "\(firstDay) \(month(first)) \u{2013} \(lastDay) \(month(last))"
    }

    /// "Study: done Monday, Tuesday; missed Wednesday; not done yet today, Friday."
    static func rowSummary(title: String, states: [WeekDayState], dayNames: [String]) -> String {
        func names(_ wanted: WeekDayState) -> String {
            states.enumerated()
                .filter { $0.element == wanted }
                .map { dayNames.indices.contains($0.offset) ? dayNames[$0.offset] : "" }
                .joined(separator: ", ")
        }
        var parts: [String] = []
        let done = names(.done)
        if !done.isEmpty { parts.append("done \(done)") }
        let missed = names(.missed)
        if !missed.isEmpty { parts.append("missed \(missed)") }
        let pending = names(.pending)
        if !pending.isEmpty { parts.append("not done yet today, \(pending)") }
        if parts.isEmpty { return "\(title): nothing due this week" }
        return "\(title): " + parts.joined(separator: "; ")
    }
}

import Foundation

/// What a calendar day means for a reading plan.
enum PlanDayState: Equatable, Sendable {
    /// Not part of the plan period (before the start or after the last planned day).
    case outside
    /// A plan day with a note written on it.
    case studied
    /// A past plan day with no note.
    case missed
    /// A future plan day.
    case upcoming
    /// Today, with no note yet. (Today with a note is `studied`; use `PlanCalendar.isToday` for the ring.)
    case today
}

/// Pure calendar logic for a book's plan. No SwiftUI, no SwiftData: everything is a function of the plan's
/// start date, the number of planned days, the dates that have a note, and "today".
struct PlanCalendar: Sendable {
    let calendar: Calendar
    /// Start of the first plan day.
    let start: Date
    let plannedDays: Int
    /// Start of today.
    let today: Date
    private let studiedDays: Set<Date>

    init(
        start: Date,
        plannedDays: Int,
        entryDates: [Date],
        today: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.start = calendar.startOfDay(for: start)
        self.plannedDays = max(plannedDays, 1)
        self.today = calendar.startOfDay(for: today)
        self.studiedDays = Set(entryDates.map { calendar.startOfDay(for: $0) })
    }

    // MARK: Plan period

    /// Start of the last planned day.
    var end: Date {
        calendar.date(byAdding: .day, value: plannedDays - 1, to: start) ?? start
    }

    func isPlanDay(_ date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= start && day <= end
    }

    /// 1-based position in the plan, or nil when the day is not a plan day.
    func dayNumber(for date: Date) -> Int? {
        guard isPlanDay(date) else { return nil }
        let day = calendar.startOfDay(for: date)
        return (calendar.dateComponents([.day], from: start, to: day).day ?? 0) + 1
    }

    func isToday(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) == today
    }

    func hasEntry(on date: Date) -> Bool {
        studiedDays.contains(calendar.startOfDay(for: date))
    }

    func state(for date: Date) -> PlanDayState {
        let day = calendar.startOfDay(for: date)
        guard isPlanDay(day) else { return .outside }
        if studiedDays.contains(day) { return .studied }
        if day == today { return .today }
        return day < today ? .missed : .upcoming
    }

    /// True for studied, missed and today: days the reader may write a note for. Future days are not open.
    func isOpen(_ date: Date) -> Bool {
        switch state(for: date) {
        case .studied, .missed, .today: return true
        case .upcoming, .outside: return false
        }
    }

    // MARK: Months

    /// First day of each month that holds at least one plan day, in order.
    var months: [Date] {
        var result: [Date] = []
        var cursor = startOfMonth(start)
        let last = startOfMonth(end)
        while cursor <= last {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// The month to show first: the one holding today when today is inside the plan, otherwise the
    /// nearest end of the plan.
    var initialMonth: Date {
        if today < start { return startOfMonth(start) }
        if today > end { return startOfMonth(end) }
        return startOfMonth(today)
    }

    func startOfMonth(_ date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? calendar.startOfDay(for: date)
    }

    /// The month after or before `month`, or nil when that month holds no plan day.
    func month(after month: Date, offset: Int) -> Date? {
        guard let next = calendar.date(byAdding: .month, value: offset, to: startOfMonth(month)) else { return nil }
        return months.contains(next) ? next : nil
    }

    /// Weeks of the month, Monday or Sunday first by the calendar's `firstWeekday`.
    /// Cells outside the month are nil. Every row has seven cells.
    func weeks(in month: Date) -> [[Date?]] {
        let first = startOfMonth(month)
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        let weekday = calendar.component(.weekday, from: first)
        let lead = (weekday - calendar.firstWeekday + 7) % 7

        var cells: [Date?] = Array(repeating: nil, count: lead)
        for offset in 0..<dayCount {
            cells.append(calendar.date(byAdding: .day, value: offset, to: first))
        }
        while cells.count % 7 != 0 { cells.append(nil) }

        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    /// The plan days that fall in `month`, in order (used for the list layout at accessibility text sizes).
    func planDays(in month: Date) -> [Date] {
        let first = startOfMonth(month)
        let dayCount = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
        return (0..<dayCount)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
            .filter { isPlanDay($0) }
    }

    /// Very short weekday symbols starting at the calendar's first weekday, for example M T W T F S S.
    func weekdaySymbols() -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + shift) % 7] }
    }

    // MARK: Entry dates

    /// The date stamped on a note written for `day`. Today keeps the current time; any other day is noon,
    /// so a time-zone change cannot move it to a neighbouring day.
    func entryDate(for day: Date, now: Date = Date()) -> Date {
        if isToday(day) { return now }
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .hour, value: 12, to: start) ?? start
    }
}

extension PlanDayState {
    /// Plain words for VoiceOver and the legend.
    var spokenName: String {
        switch self {
        case .outside: return "not in this plan"
        case .studied: return "studied"
        case .missed: return "missed"
        case .upcoming: return "still to come"
        case .today: return "today"
        }
    }
}

import Foundation
import Testing
@testable import Selah

struct ActivityCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    private func build(_ year: Int, dates: [Date] = [], today: Date, binary: Bool = false) -> ActivityYear {
        ActivityCalendar.year(year, dates: dates, today: today, binary: binary, calendar: calendar)
    }

    // MARK: Layout

    @Test func leapYearHas366CellsInYear() {
        let data = build(2024, today: date(2024, 6, 1))
        let inYear = data.weeks.flatMap { $0.days }.filter { $0.isInYear }
        #expect(inYear.count == 366)
        #expect(build(2026, today: date(2026, 6, 1)).weeks.flatMap { $0.days }.filter { $0.isInYear }.count == 365)
    }

    @Test func everyWeekIsSevenDaysAndStartsOnMonday() {
        let data = build(2026, today: date(2026, 10, 18))
        for week in data.weeks {
            #expect(week.days.count == 7)
            #expect(calendar.component(.weekday, from: week.start) == 2)
        }
    }

    @Test func firstWeekIsPaddedWhenYearStartsMidWeek() {
        // 1 Jan 2026 is a Thursday: Mon, Tue and Wed belong to 2025.
        let first = build(2026, today: date(2026, 6, 1)).weeks[0]
        #expect(first.days.map { $0.isInYear } == [false, false, false, true, true, true, true])
        #expect(calendar.component(.day, from: first.days[3].date) == 1)
    }

    @Test func firstWeekIsFullWhenYearStartsOnMonday() {
        // 1 Jan 2024 is a Monday.
        let first = build(2024, today: date(2024, 6, 1)).weeks[0]
        #expect(first.days.allSatisfy { $0.isInYear })
    }

    @Test func monthLabelsSitInTheColumnOfTheFirst() {
        let data = build(2026, today: date(2026, 6, 1))
        #expect(data.monthLabels.count == 12)
        #expect(data.monthLabels.first?.month == 1)
        #expect(data.monthLabels.first?.weekIndex == 0)
        // 1 Feb 2026 is a Sunday in the week of Monday 26 Jan: four weeks after the week of 29 Dec.
        #expect(data.monthLabels[1].weekIndex == 4)
        // 1 Mar 2026 is a Sunday in the week of Monday 23 Feb.
        #expect(data.monthLabels[2].weekIndex == 8)
        // Indexes only go up.
        let indexes = data.monthLabels.map { $0.weekIndex }
        #expect(indexes == indexes.sorted())
        #expect(Set(indexes).count == 12)
    }

    @Test func currentWeekIndexHoldsToday() {
        let today = date(2026, 10, 18)
        let data = build(2026, today: today)
        let index = data.currentWeekIndex ?? -1
        #expect(data.weeks.indices.contains(index))
        if data.weeks.indices.contains(index) {
            #expect(data.weeks[index].days.contains { $0.isToday })
        }
        #expect(build(2025, today: today).currentWeekIndex == nil)
    }

    // MARK: Levels

    @Test func levelsFollowTheCount() {
        #expect(ActivityCalendar.level(count: 0) == 0)
        #expect(ActivityCalendar.level(count: 1) == 1)
        #expect(ActivityCalendar.level(count: 2) == 2)
        #expect(ActivityCalendar.level(count: 3) == 3)
        #expect(ActivityCalendar.level(count: 4) == 4)
        #expect(ActivityCalendar.level(count: 9) == 4)
    }

    @Test func binarySourcesAreEmptyOrFull() {
        #expect(ActivityCalendar.level(count: 0, binary: true) == 0)
        #expect(ActivityCalendar.level(count: 1, binary: true) == 4)
        #expect(ActivityCalendar.level(count: 3, binary: true) == 4)
    }

    // MARK: Totals

    @Test func totalsCountOnlyTheYear() {
        let dates = [
            date(2026, 1, 1, 8), date(2026, 1, 1, 20), date(2026, 3, 5),
            date(2026, 10, 18), date(2025, 12, 31), date(2027, 1, 1)
        ]
        let data = build(2026, dates: dates, today: date(2026, 10, 18))
        #expect(data.total == 4)
        #expect(data.activeDays == 3)
        #expect(data.months[0].count == 2)
        #expect(data.months[0].activeDays == 1)
        #expect(data.months[2].count == 1)
        #expect(data.months.count == 12)
    }

    @Test func dayLevelsAndFlags() {
        let today = date(2026, 10, 18)
        let data = build(2026, dates: [date(2026, 10, 18), date(2026, 10, 18), date(2026, 10, 17)], today: today)
        let days = data.weeks.flatMap { $0.days }
        #expect(days.first { $0.isToday }?.level == 2)
        #expect(days.first { calendar.isDate($0.date, inSameDayAs: date(2026, 10, 17)) }?.level == 1)
        #expect(days.first { calendar.isDate($0.date, inSameDayAs: date(2026, 10, 19)) }?.isFuture == true)
    }

    // MARK: Streak

    @Test func streakReusesTheStudyRules() {
        let today = date(2026, 10, 18)
        let dates = [date(2026, 10, 18), date(2026, 10, 17), date(2026, 10, 16), date(2026, 10, 12)]
        #expect(ActivityCalendar.studyStreak(dates: dates, today: today, calendar: calendar) == 3)
        #expect(ActivityCalendar.studyStreak(dates: [], today: today, calendar: calendar) == 0)
    }

    // MARK: Habit week

    @Test func overallRowMatchesStreaksWeek() {
        let today = date(2026, 10, 18)
        let input = StreakInput(
            studyDates: [date(2026, 10, 13), date(2026, 10, 14), date(2026, 10, 18)],
            serviceDates: [date(2026, 10, 14)],
            meetingWeekdays: [4],
            readingSpans: [ReadingSpan(start: date(2026, 10, 12), end: nil)]
        )
        let expected = Streaks.week(input, today: today, calendar: calendar).map { $0.state }
        let states = ActivityCalendar.weekStates(input, weekOf: today, today: today, calendar: calendar)
        #expect(states.overall == expected)
        #expect(states.todayIndex == 6)
        #expect(states.days.count == 7)
    }

    @Test func pastWeekHasNoPendingDay() {
        let today = date(2026, 10, 18)
        let input = StreakInput(
            studyDates: [date(2026, 10, 6)],
            readingSpans: [ReadingSpan(start: date(2026, 10, 1), end: nil)]
        )
        let states = ActivityCalendar.weekStates(input, weekOf: date(2026, 10, 7), today: today, calendar: calendar)
        #expect(states.todayIndex == nil)
        #expect(states.study[1] == .done)
        #expect(states.study[0] == .missed)
        #expect(!states.study.contains(.pending))
    }

    @Test func serviceRowOnlyFollowsMeetingDays() {
        let today = date(2026, 10, 18)
        // Wednesdays (weekday 4); 14 Oct has a service, nothing else is due.
        let input = StreakInput(serviceDates: [date(2026, 10, 14)], meetingWeekdays: [4])
        let states = ActivityCalendar.weekStates(input, weekOf: today, today: today, calendar: calendar)
        #expect(states.service[2] == .done)
        #expect(states.service[0] == .none)
        #expect(states.study.allSatisfy { $0 == .none })
    }

    @Test func todayWithWorkOpenIsPending() {
        let today = date(2026, 10, 18)
        let input = StreakInput(readingSpans: [ReadingSpan(start: date(2026, 10, 1), end: nil)])
        let states = ActivityCalendar.weekStates(input, weekOf: today, today: today, calendar: calendar)
        #expect(states.study[6] == .pending)
        #expect(states.overall[6] == .pending)
    }

    @Test func weekRangeLabels() {
        #expect(ActivityCalendar.weekRangeLabel(start: date(2026, 10, 12), calendar: calendar) == "12 \u{2013} 18 Oct")
        #expect(ActivityCalendar.weekRangeLabel(start: date(2026, 9, 28), calendar: calendar) == "28 Sep \u{2013} 4 Oct")
    }

    @Test func weekStartIsMonday() {
        let monday = ActivityCalendar.weekStart(containing: date(2026, 10, 18), calendar: calendar)
        #expect(calendar.component(.day, from: monday) == 12)
    }

    @Test func rowSummaryNamesTheDays() {
        let text = ActivityCalendar.rowSummary(
            title: "Study",
            states: [.done, .done, .missed, .none, .pending, .none, .none],
            dayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        )
        #expect(text == "Study: done Monday, Tuesday; missed Wednesday; not done yet today, Friday")
        #expect(ActivityCalendar.rowSummary(title: "Service", states: Array(repeating: .none, count: 7), dayNames: [])
            == "Service: nothing due this week")
    }
}

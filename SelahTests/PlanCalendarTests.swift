import Foundation
import Testing
@testable import Selah

struct PlanCalendarTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.firstWeekday = 1 // Sunday
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 9) -> Date {
        let parts = DateComponents(year: year, month: month, day: day, hour: hour)
        return calendar.date(from: parts) ?? Date()
    }

    private func makeCalendar(
        start: Date,
        days: Int,
        entries: [Date] = [],
        today: Date
    ) -> PlanCalendar {
        PlanCalendar(start: start, plannedDays: days, entryDates: entries, today: today, calendar: calendar)
    }

    @Test func statesForStudiedMissedTodayAndUpcoming() {
        // 7-day plan from Mon 12 Oct 2026; today is Thu 15 Oct.
        let plan = makeCalendar(
            start: date(2026, 10, 12),
            days: 7,
            entries: [date(2026, 10, 12, hour: 20), date(2026, 10, 14)],
            today: date(2026, 10, 15, hour: 18)
        )
        #expect(plan.state(for: date(2026, 10, 12)) == .studied)
        #expect(plan.state(for: date(2026, 10, 13)) == .missed)
        #expect(plan.state(for: date(2026, 10, 14)) == .studied)
        #expect(plan.state(for: date(2026, 10, 15)) == .today)
        #expect(plan.state(for: date(2026, 10, 16)) == .upcoming)
        #expect(plan.state(for: date(2026, 10, 18)) == .upcoming)
    }

    @Test func todayWithANoteIsStudiedButStillToday() {
        let plan = makeCalendar(
            start: date(2026, 10, 12),
            days: 7,
            entries: [date(2026, 10, 15, hour: 7)],
            today: date(2026, 10, 15, hour: 22)
        )
        #expect(plan.state(for: date(2026, 10, 15)) == .studied)
        #expect(plan.isToday(date(2026, 10, 15, hour: 1)))
    }

    @Test func daysOutsideThePlanAreOutside() {
        let plan = makeCalendar(start: date(2026, 10, 12), days: 7, today: date(2026, 10, 15))
        #expect(plan.state(for: date(2026, 10, 11)) == .outside)
        #expect(plan.state(for: date(2026, 10, 19)) == .outside)
        #expect(plan.dayNumber(for: date(2026, 10, 12)) == 1)
        #expect(plan.dayNumber(for: date(2026, 10, 18)) == 7)
        #expect(plan.dayNumber(for: date(2026, 10, 19)) == nil)
        #expect(plan.isOpen(date(2026, 10, 15)))
        #expect(!plan.isOpen(date(2026, 10, 16)))
        #expect(!plan.isOpen(date(2026, 10, 19)))
    }

    @Test func noteOutsideThePlanDoesNotMakeItStudied() {
        let plan = makeCalendar(
            start: date(2026, 10, 12),
            days: 3,
            entries: [date(2026, 10, 1)],
            today: date(2026, 10, 15)
        )
        #expect(plan.state(for: date(2026, 10, 1)) == .outside)
    }

    @Test func planDayBeforeTodayWithoutNoteIsMissedAcrossAMonthBoundary() {
        // 5-day plan from Wed 29 Oct to Sun 2 Nov, today is Fri 31 Oct.
        let plan = makeCalendar(
            start: date(2026, 10, 29),
            days: 5,
            entries: [date(2026, 10, 29)],
            today: date(2026, 10, 31)
        )
        #expect(plan.end == calendar.startOfDay(for: date(2026, 11, 2)))
        #expect(plan.state(for: date(2026, 10, 30)) == .missed)
        #expect(plan.state(for: date(2026, 10, 31)) == .today)
        #expect(plan.state(for: date(2026, 11, 1)) == .upcoming)
        #expect(plan.months == [date(2026, 10, 1, hour: 0), date(2026, 11, 1, hour: 0)])
        #expect(plan.planDays(in: date(2026, 10, 1)).count == 3)
        #expect(plan.planDays(in: date(2026, 11, 1)).count == 2)
    }

    @Test func planLongerThanAMonthListsEveryMonthItTouches() {
        let plan = makeCalendar(start: date(2026, 10, 20), days: 75, today: date(2026, 11, 20))
        // 20 Oct + 74 days = 2 Jan 2027.
        #expect(plan.end == calendar.startOfDay(for: date(2027, 1, 2)))
        #expect(plan.months.count == 4)
        #expect(plan.months.first == date(2026, 10, 1, hour: 0))
        #expect(plan.months.last == date(2027, 1, 1, hour: 0))
        #expect(plan.initialMonth == date(2026, 11, 1, hour: 0))
        #expect(plan.month(after: plan.initialMonth, offset: 1) == date(2026, 12, 1, hour: 0))
        #expect(plan.month(after: plan.initialMonth, offset: -1) == date(2026, 10, 1, hour: 0))
        #expect(plan.month(after: date(2027, 1, 1, hour: 0), offset: 1) == nil)
        #expect(plan.month(after: date(2026, 10, 1, hour: 0), offset: -1) == nil)
    }

    @Test func initialMonthClampsToThePlanWhenTodayIsOutsideIt() {
        let before = makeCalendar(start: date(2026, 11, 5), days: 10, today: date(2026, 10, 18))
        #expect(before.initialMonth == date(2026, 11, 1, hour: 0))
        let after = makeCalendar(start: date(2026, 8, 5), days: 10, today: date(2026, 10, 18))
        #expect(after.initialMonth == date(2026, 8, 1, hour: 0))
    }

    @Test func weeksPadWithNilAndHaveSevenCellsPerRow() {
        // October 2026 starts on a Thursday and has 31 days. Sunday first: 4 leading blanks.
        let plan = makeCalendar(start: date(2026, 10, 1), days: 31, today: date(2026, 10, 15))
        let weeks = plan.weeks(in: date(2026, 10, 1))
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(weeks.count == 5)
        #expect(weeks[0].prefix(4).allSatisfy { $0 == nil })
        #expect(weeks[0][4] == calendar.startOfDay(for: date(2026, 10, 1)))
        #expect(weeks.flatMap { $0 }.compactMap { $0 }.count == 31)
    }

    @Test func mondayFirstShiftsTheLeadingBlanks() {
        var monday = calendar
        monday.firstWeekday = 2
        let plan = PlanCalendar(
            start: date(2026, 10, 1),
            plannedDays: 31,
            entryDates: [],
            today: date(2026, 10, 15),
            calendar: monday
        )
        let weeks = plan.weeks(in: date(2026, 10, 1))
        // Thursday is the fourth day when the week starts on Monday: 3 blanks.
        #expect(weeks[0].prefix(3).allSatisfy { $0 == nil })
        #expect(weeks[0][3] != nil)
        #expect(plan.weekdaySymbols().count == 7)
    }

    @Test func leapFebruaryHasTwentyNineDays() {
        let plan = makeCalendar(start: date(2028, 2, 1), days: 29, today: date(2028, 2, 10))
        let days = plan.weeks(in: date(2028, 2, 1)).flatMap { $0 }.compactMap { $0 }
        #expect(days.count == 29)
        #expect(plan.months.count == 1)
    }

    @Test func entryDateKeepsTheTimeForTodayAndUsesNoonOtherwise() {
        let now = date(2026, 10, 15, hour: 17)
        let plan = makeCalendar(start: date(2026, 10, 12), days: 7, today: now)
        #expect(plan.entryDate(for: date(2026, 10, 15, hour: 0), now: now) == now)
        let past = plan.entryDate(for: date(2026, 10, 13, hour: 2), now: now)
        #expect(past == date(2026, 10, 13, hour: 12))
        #expect(plan.state(for: past) == .missed)
    }

    @Test func plannedDaysAreClampedToAtLeastOne() {
        let plan = makeCalendar(start: date(2026, 10, 12), days: 0, today: date(2026, 10, 12))
        #expect(plan.plannedDays == 1)
        #expect(plan.end == plan.start)
    }
}

import Foundation
import Testing
@testable import Selah

struct StreakTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// October 2026: the 18th is a Sunday (weekday 1), the 13th and 20th are Tuesdays (weekday 3).
    private func day(_ day: Int, _ hour: Int = 12) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 10
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts) ?? Date()
    }

    private var today: Date { day(18, 20) }

    private func summary(_ input: StreakInput) -> StreakSummary {
        Streaks.summary(input, today: today, calendar: calendar)
    }

    // MARK: Study

    @Test func studyStreakCountsConsecutiveDaysEndingToday() {
        let result = summary(StreakInput(studyDates: [day(16), day(17), day(18, 7)]))
        #expect(result.study.current == 3)
        #expect(result.study.doneToday)
    }

    @Test func studyStreakSurvivesTodayNotDoneYet() {
        let result = summary(StreakInput(studyDates: [day(15), day(16), day(17)]))
        #expect(result.study.current == 3)
        #expect(result.study.doneToday == false)
    }

    @Test func aMissedDayUsesAFreezeAndTheStreakHolds() {
        // 17 October is missed: a freeze covers it, the streak stays at 2 (the frozen day doesn't add to it).
        let result = summary(StreakInput(studyDates: [day(15), day(16)]))
        #expect(result.study.current == 2)
        #expect(result.study.best == 2)
        #expect(result.study.freezesLeft == 4)
        #expect(result.study.frozenDays == [calendar.startOfDay(for: day(17))])
    }

    @Test func comingBackAfterAFrozenDayCarriesOn() {
        let result = summary(StreakInput(studyDates: [day(15), day(16), day(18)]))
        #expect(result.study.current == 3)
        #expect(result.study.freezesLeft == 4)
    }

    @Test func withNoFreezesLeftAMissResetsTheStreak() {
        // 1 to 4 October read, then 12 days missed: 5 to 9 use the month's 5 freezes, 10 resets the streak to 0.
        let dates = [1, 2, 3, 4, 17, 18].map { day($0) }
        let result = summary(StreakInput(studyDates: dates))
        #expect(result.study.current == 2)
        #expect(result.study.best == 4)
        #expect(result.study.freezesLeft == 0)
        #expect(result.study.frozenDays.count == 5)
    }

    @Test func aMissWhileTheStreakIsZeroUsesNoFreeze() {
        // A study day long ago starts the look-back; the misses after the reset don't spend freezes.
        let result = summary(StreakInput(studyDates: [day(1), day(18)]))
        #expect(result.study.current == 1)
        #expect(result.study.frozenDays.count == 5)
        #expect(result.study.freezesLeft == 0)
    }

    @Test func freezesRefillEachMonth() {
        func date(_ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 12)) ?? Date()
        }
        // Read 1 to 24 September, then nothing from 25 September to 4 October.
        // September's 5 freezes cover 25 to 29; 30 September resets the streak.
        let september = (1...24).map { date(9, $0) }
        let late = Streaks.summary(StreakInput(studyDates: september), today: date(10, 4), calendar: calendar)
        #expect(late.study.current == 0)
        // Read through 26 September, miss 27 September to 3 October, read on 4 October:
        // 27 to 30 September use 4 of September's freezes, 1 to 3 October use 3 of October's.
        let soon = (1...26).map { date(9, $0) } + [date(10, 4)]
        let back = Streaks.summary(StreakInput(studyDates: soon), today: date(10, 4), calendar: calendar)
        #expect(back.study.current == 27)
        #expect(back.study.freezesLeft == 2)
    }

    @Test func studyBestIsTheLongestRun() {
        let dates = [10, 11, 12, 13, 17, 18].map { day($0) }
        let result = summary(StreakInput(studyDates: dates))
        // 14 to 16 are frozen, so the run carries on: 4 + 2.
        #expect(result.study.current == 6)
        #expect(result.study.best == 6)
        #expect(result.study.freezesLeft == 2)
    }

    @Test func severalEntriesOnOneDayCountOnce() {
        let result = summary(StreakInput(studyDates: [day(17, 8), day(17, 20), day(18)]))
        #expect(result.study.current == 2)
    }

    @Test func noDataMeansNoStreaks() {
        let result = summary(StreakInput())
        #expect(result == StreakSummary())
    }

    // MARK: Service

    private let sundayAndTuesday: Set<Int> = [1, 3]

    @Test func serviceStreakCountsRecordedMeetings() {
        let input = StreakInput(
            serviceDates: [day(11), day(13), day(18)],
            meetingWeekdays: sundayAndTuesday
        )
        let result = summary(input)
        #expect(result.service.current == 3)
        #expect(result.service.doneToday)
    }

    @Test func meetingStillToComeTodayDoesNotBreakTheServiceStreak() {
        let input = StreakInput(serviceDates: [day(11), day(13)], meetingWeekdays: sundayAndTuesday)
        let result = summary(input)
        #expect(result.service.current == 2)
        #expect(result.service.doneToday == false)
    }

    @Test func missedMeetingUsesAServiceFreeze() {
        // The Tuesday 13 meeting is missed: a freeze holds the streak.
        let input = StreakInput(serviceDates: [day(11), day(18)], meetingWeekdays: sundayAndTuesday)
        let result = summary(input)
        #expect(result.service.current == 2)
        #expect(result.service.best == 2)
        #expect(result.service.freezesLeft == 4)
    }

    @Test func daysBetweenMeetingsAreSkippedAndExtraServicesDoNotCount() {
        // 15 October is a Thursday, not a meeting day.
        let input = StreakInput(
            serviceDates: [day(11), day(13), day(15), day(18)],
            meetingWeekdays: sundayAndTuesday
        )
        #expect(summary(input).service.current == 3)
    }

    @Test func noMeetingDaysMeansNoServiceStreak() {
        let result = summary(StreakInput(serviceDates: [day(11), day(18)], meetingWeekdays: []))
        #expect(result.service.current == 0)
    }

    // MARK: Overall

    @Test func overallNeedsStudyAndServiceOnMeetingDays() {
        let input = StreakInput(
            studyDates: [14, 15, 16, 17, 18].map { day($0) },
            serviceDates: [day(18)],
            meetingWeekdays: [1],
            readingSpans: [ReadingSpan(start: day(14), end: nil)]
        )
        let result = summary(input)
        #expect(result.overall.current == 5)
        #expect(result.overall.doneToday)
    }

    @Test func overallTodayStillOpenDoesNotBreakIt() {
        let input = StreakInput(
            studyDates: [14, 15, 16, 17].map { day($0) },
            serviceDates: [],
            meetingWeekdays: [1],
            readingSpans: [ReadingSpan(start: day(14), end: nil)]
        )
        let result = summary(input)
        #expect(result.overall.current == 4)
        #expect(result.overall.doneToday == false)
    }

    @Test func overallBreaksWhenADueStudyIsMissed() {
        let input = StreakInput(
            studyDates: [14, 15, 17, 18].map { day($0) },
            serviceDates: [day(18)],
            meetingWeekdays: [1],
            readingSpans: [ReadingSpan(start: day(14), end: nil)]
        )
        let result = summary(input)
        // 16 is frozen, so the run carries on.
        #expect(result.overall.current == 4)
        #expect(result.overall.best == 4)
    }

    @Test func daysWithNothingDueNeitherBreakNorExtend() {
        // Only Tuesday is a meeting day and no book is being read: 13 is done, the rest have nothing due.
        let input = StreakInput(serviceDates: [day(13)], meetingWeekdays: [3])
        let result = summary(input)
        #expect(result.overall.current == 1)
        #expect(result.overall.best == 1)
    }

    @Test func finishedBookStopsRequiringStudy() {
        let input = StreakInput(
            studyDates: [10, 11, 12].map { day($0) },
            readingSpans: [ReadingSpan(start: day(10), end: day(12))]
        )
        let result = summary(input)
        #expect(result.overall.current == 3)
        #expect(result.overall.doneToday == false)
    }

    // MARK: Week

    @Test func weekRunsMondayToSundayWithStates() {
        let input = StreakInput(
            studyDates: [day(12, 8), day(12, 9), day(13)],
            readingSpans: [ReadingSpan(start: day(12), end: nil)]
        )
        let week = Streaks.week(input, today: today, calendar: calendar)
        #expect(week.count == 7)
        #expect(calendar.component(.weekday, from: week[0].date) == 2)
        #expect(week[0].state == .done)
        #expect(week[0].studyCount == 2)
        #expect(week[1].state == .done)
        // Wednesday was missed while the streak was running: a freeze covered it.
        #expect(week[2].state == .frozen)
        #expect(week[6].isToday)
        #expect(week[6].state == .pending)
    }

    @Test func futureDaysAndDaysWithNothingDueAreDim() {
        let wednesday = day(14)
        let input = StreakInput(studyDates: [day(14)], readingSpans: [ReadingSpan(start: day(14), end: nil)])
        let week = Streaks.week(input, today: wednesday, calendar: calendar)
        #expect(week[0].state == .none)
        #expect(week[2].state == .done)
        #expect(week[3].state == .none)
    }

    // MARK: Countdown

    @Test func countdownText() {
        #expect(GatheringCountdown.text(daysAway: 0, todayText: "Tonight 18:30") == "Tonight 18:30")
        #expect(GatheringCountdown.text(daysAway: 1, todayText: "x") == "Tomorrow")
        #expect(GatheringCountdown.text(daysAway: 2, todayText: "x") == "in 2 days")
        #expect(GatheringCountdown.daysAway(from: day(18, 20), to: day(20, 9), calendar: calendar) == 2)
        #expect(GatheringCountdown.daysAway(from: day(18, 9), to: day(18, 20), calendar: calendar) == 0)
    }
}

import Foundation
import Testing
@testable import Selah

struct TodaySummaryTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// October 2026: the 18th is a Sunday (weekday 1), the 20th a Tuesday (weekday 3).
    private func date(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 10
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return calendar.date(from: parts) ?? Date()
    }

    private let tuesdayStudy = MeetingSlot(name: "Bible study", weekday: 3, hour: 18, minute: 30)
    private let sundayWorship = MeetingSlot(name: "Sunday worship", weekday: 1, hour: 9, minute: 0)

    @Test func laterTodayIsTonight() {
        let result = TodaySummary.nextGathering(from: [tuesdayStudy, sundayWorship], now: date(20, 12), calendar: calendar)
        #expect(result?.name == "Bible study")
        #expect(result?.isToday == true)
        #expect(result?.text == "Tonight 18:30")
        #expect(result?.date == date(20, 18, 30))
    }

    @Test func alreadyPassedTodayMovesToNextMeeting() {
        let result = TodaySummary.nextGathering(from: [tuesdayStudy, sundayWorship], now: date(20, 20), calendar: calendar)
        #expect(result?.name == "Sunday worship")
        #expect(result?.isToday == false)
        #expect(result?.text == "Sunday 09:00")
        #expect(result?.date == date(25, 9))
    }

    @Test func wrapsToNextWeek() {
        let result = TodaySummary.nextGathering(from: [tuesdayStudy], now: date(20, 20), calendar: calendar)
        #expect(result?.date == date(27, 18, 30))
        #expect(result?.isToday == false)
        #expect(result?.text == "Tuesday 18:30")
    }

    @Test func tomorrowIsLabelledTomorrow() {
        let result = TodaySummary.nextGathering(from: [tuesdayStudy], now: date(19, 10), calendar: calendar)
        #expect(result?.text == "Tomorrow 18:30")
    }

    @Test func morningMeetingTodayIsLabelledToday() {
        let result = TodaySummary.nextGathering(from: [sundayWorship], now: date(18, 7), calendar: calendar)
        #expect(result?.isToday == true)
        #expect(result?.text == "Today 09:00")
    }

    @Test func inactiveDaysAreIgnored() {
        var inactive = tuesdayStudy
        inactive.isActive = false
        let result = TodaySummary.nextGathering(from: [inactive, sundayWorship], now: date(20, 12), calendar: calendar)
        #expect(result?.name == "Sunday worship")
    }

    @Test func noDaysGivesNil() {
        #expect(TodaySummary.nextGathering(from: [], now: date(20, 12), calendar: calendar) == nil)
        var inactive = tuesdayStudy
        inactive.isActive = false
        #expect(TodaySummary.nextGathering(from: [inactive], now: date(20, 12), calendar: calendar) == nil)
    }

    @Test func emptyNameFallsBackToWeekday() {
        let slot = MeetingSlot(name: "  ", weekday: 3, hour: 18, minute: 30)
        let result = TodaySummary.nextGathering(from: [slot], now: date(20, 12), calendar: calendar)
        #expect(result?.name == "Tuesday")
    }

    // MARK: Reading

    @Test func readingItemShowsNextChapterAndDay() {
        let plan = ReadingSnapshot(
            bookName: "Philippians",
            status: .reading,
            chaptersRead: [1, 2],
            totalChapters: 4,
            plannedDays: 4,
            startDate: date(16, 8)
        )
        let item = TodaySummary.readingItem(for: plan, hasEntryToday: false, now: date(18, 8), calendar: calendar)
        #expect(item?.nextChapter == 3)
        #expect(item?.dayText == "Day 3 of 4")
        #expect(item?.chaptersPerDay == 1)
        #expect(item?.paceText == "1 chapter a day")
        #expect(item?.hasEntryToday == false)
    }

    @Test func readingItemSkipsGapsInReadChapters() {
        let plan = ReadingSnapshot(
            bookName: "John", status: .reading, chaptersRead: [1, 3], totalChapters: 21, plannedDays: 7, startDate: date(18, 8)
        )
        let item = TodaySummary.readingItem(for: plan, hasEntryToday: true, now: date(18, 9), calendar: calendar)
        #expect(item?.nextChapter == 2)
        #expect(item?.dayText == "Day 1 of 7")
        #expect(item?.paceText == "3 chapters a day")
        #expect(item?.hasEntryToday == true)
    }

    @Test func readingItemOnlyForReadingStatus() {
        let plan = ReadingSnapshot(
            bookName: "Ruth", status: .upNext, chaptersRead: [], totalChapters: 4, plannedDays: 4, startDate: nil
        )
        #expect(TodaySummary.readingItem(for: plan, hasEntryToday: false, now: date(18, 8), calendar: calendar) == nil)
    }

    @Test func hasEntryMatchesSameDayOnly() {
        #expect(TodaySummary.hasEntry(on: date(18, 20), dates: [date(17, 23), date(18, 6)], calendar: calendar))
        #expect(!TodaySummary.hasEntry(on: date(18, 20), dates: [date(17, 23), date(19, 1)], calendar: calendar))
    }
}

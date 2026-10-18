import Foundation
import Testing
@testable import Selah

struct QuietTimeLogicTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        // Without a locale the weekday names fall back to short forms.
        c.locale = Locale(identifier: "en_US")
        return c
    }

    // MARK: Schedule list

    @Test func servicesAreSortedByWeekdayThenTime() {
        let meetings = [
            ServiceMeetingSnapshot(weekday: 3, hour: 18, minute: 30, name: "Bible study"),
            ServiceMeetingSnapshot(weekday: 1, hour: 11, minute: 0, name: "Sunday evening"),
            ServiceMeetingSnapshot(weekday: 1, hour: 9, minute: 0, name: "Sunday worship"),
        ]
        let items = QuietScheduleBuilder.items(meetings: meetings, reading: [], calendar: calendar)
        #expect(items.map(\.label) == [
            "Sunday 09:00 · Sunday worship",
            "Sunday 11:00 · Sunday evening",
            "Tuesday 18:30 · Bible study",
        ])
        #expect(items.allSatisfy { $0.kind == .service && $0.actionName == "Start service notes" })
    }

    @Test func inactiveMeetingDaysAreLeftOut() {
        let meetings = [
            ServiceMeetingSnapshot(weekday: 3, hour: 18, minute: 30, name: "Bible study", isActive: false),
            ServiceMeetingSnapshot(weekday: 1, hour: 9, minute: 0, name: "Sunday worship"),
        ]
        let items = QuietScheduleBuilder.items(meetings: meetings, reading: [], calendar: calendar)
        #expect(items.count == 1)
        #expect(items.first?.title == "Sunday worship")
    }

    @Test func emptyMeetingNameUsesTheWeekdayName() {
        let meetings = [ServiceMeetingSnapshot(weekday: 4, hour: 7, minute: 5, name: "  ")]
        let items = QuietScheduleBuilder.items(meetings: meetings, reading: [], calendar: calendar)
        #expect(items.first?.label == "Wednesday 07:05 · Wednesday")
    }

    @Test func readingTimesAreDailyAndComeAfterServices() {
        let meetings = [ServiceMeetingSnapshot(weekday: 1, hour: 9, minute: 0, name: "Sunday worship")]
        let reading = [
            QuietReadingTime(bookName: "Philippians", hour: 7, minute: 0),
            QuietReadingTime(bookName: "James", hour: 6, minute: 30),
        ]
        let items = QuietScheduleBuilder.items(meetings: meetings, reading: reading, calendar: calendar)
        #expect(items.map(\.label) == [
            "Sunday 09:00 · Sunday worship",
            "Daily 06:30 · James",
            "Daily 07:00 · Philippians",
        ])
        #expect(items[1].kind == .study)
        #expect(items[1].weekday == nil)
        #expect(items[1].actionName == "Start study session")
    }

    @Test func sameBookAndTimeIsListedOnce() {
        let reading = [
            QuietReadingTime(bookName: "Philippians", hour: 7, minute: 0),
            QuietReadingTime(bookName: "Philippians", hour: 7, minute: 0),
            QuietReadingTime(bookName: "Philippians", hour: 20, minute: 0),
        ]
        let items = QuietScheduleBuilder.items(meetings: [], reading: reading, calendar: calendar)
        #expect(items.count == 2)
    }

    @Test func nothingToScheduleGivesAnEmptyList() {
        #expect(QuietScheduleBuilder.items(meetings: [], reading: [], calendar: calendar).isEmpty)
    }

    // MARK: Destination mapping

    @Test func focusFilterChoiceMapsToDestination() {
        #expect(QuietOpenTo.today.destination == .today)
        #expect(QuietOpenTo.studySession.destination == .studySession)
        #expect(QuietOpenTo.serviceNotes.destination == .serviceNotes)
    }

    @Test func everyChoiceHasADistinctDestination() {
        let all = QuietOpenTo.allCases.map(\.destination)
        #expect(Set(all).count == QuietOpenTo.allCases.count)
    }

    // MARK: Once per Focus session

    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func noRecordOpensNothing() {
        #expect(QuietFocusRule.destinationToOpen(nil, now: start) == nil)
    }

    @Test func freshActivationOpensItsDestination() {
        let record = QuietFocusRecord(destination: .studySession, activatedAt: start, handledAt: nil)
        let now = start.addingTimeInterval(60)
        #expect(QuietFocusRule.destinationToOpen(record, now: now) == .studySession)
    }

    @Test func aHandledActivationNeverOpensAgain() {
        let record = QuietFocusRecord(destination: .today, activatedAt: start, handledAt: start)
        let now = start.addingTimeInterval(60)
        #expect(QuietFocusRule.destinationToOpen(record, now: now) == nil)
    }

    @Test func aNewActivationOpensOnceMore() {
        let later = start.addingTimeInterval(3 * 60 * 60)
        let record = QuietFocusRecord(destination: .serviceNotes, activatedAt: later, handledAt: start)
        let now = later.addingTimeInterval(30)
        #expect(QuietFocusRule.destinationToOpen(record, now: now) == .serviceNotes)
    }

    @Test func aStaleActivationIsIgnored() {
        let record = QuietFocusRecord(destination: .today, activatedAt: start, handledAt: nil)
        let now = start.addingTimeInterval(QuietFocusRule.maxAge + 1)
        #expect(QuietFocusRule.destinationToOpen(record, now: now) == nil)
    }

    @Test func storeRoundTripFollowsTheRule() throws {
        let suite = "quiet-test-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(QuietFocusStore.load(defaults: defaults) == nil)

        QuietFocusStore.recordActivation(destination: .serviceNotes, at: start, defaults: defaults)
        let first = try #require(QuietFocusStore.load(defaults: defaults))
        #expect(first.destination == .serviceNotes)
        #expect(first.handledAt == nil)
        #expect(QuietFocusRule.destinationToOpen(first, now: start.addingTimeInterval(5)) == .serviceNotes)

        QuietFocusStore.markHandled(first, defaults: defaults)
        let handled = try #require(QuietFocusStore.load(defaults: defaults))
        #expect(QuietFocusRule.destinationToOpen(handled, now: start.addingTimeInterval(10)) == nil)

        // A new activation resets the handled flag.
        QuietFocusStore.recordActivation(destination: .today, at: start.addingTimeInterval(600), defaults: defaults)
        let second = try #require(QuietFocusStore.load(defaults: defaults))
        #expect(QuietFocusRule.destinationToOpen(second, now: start.addingTimeInterval(620)) == .today)
    }
}

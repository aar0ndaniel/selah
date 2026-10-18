import Foundation
import Testing
@testable import Selah

struct ServicesLogicTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        // Without a locale the calendar falls back to short day names ("Sun").
        c.locale = Locale(identifier: "en_US")
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour)) ?? Date()
    }

    // 18 October 2026 is a Sunday (weekday 1); 19 October is a Monday.
    private let sunday = ServiceMeetingSnapshot(weekday: 1, hour: 9, minute: 0, name: "Sunday worship")

    @Test func todayIsMeetingDayGivesPrompt() {
        let prompt = ServicesLogic.todayPrompt(
            meetings: [sunday], services: [], on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.name == "Sunday worship")
        #expect(prompt?.title == "Today · Sunday worship 09:00")
        #expect(prompt?.buttonTitle == "Add notes for today's service")
        #expect(prompt?.hasExistingService == false)
    }

    @Test func notAMeetingDayGivesNoPrompt() {
        let prompt = ServicesLogic.todayPrompt(
            meetings: [sunday], services: [], on: date(2026, 10, 19), calendar: calendar
        )
        #expect(prompt == nil)
    }

    @Test func inactiveMeetingDayDoesNotCount() {
        var off = sunday
        off.isActive = false
        let prompt = ServicesLogic.todayPrompt(
            meetings: [off], services: [], on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt == nil)
    }

    @Test func noMeetingDaysGivesNoPrompt() {
        #expect(ServicesLogic.todayPrompt(meetings: [], services: [], on: date(2026, 10, 18), calendar: calendar) == nil)
    }

    @Test func existingServiceTodayChangesTheButton() {
        let services = [
            ServiceStub(date: date(2026, 10, 11), gatheringName: "Sunday worship"),
            ServiceStub(date: date(2026, 10, 18, hour: 10), gatheringName: "Sunday worship"),
        ]
        let prompt = ServicesLogic.todayPrompt(
            meetings: [sunday], services: services, on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.existingServiceIndex == 1)
        #expect(prompt?.buttonTitle == "Open today's service")
    }

    @Test func lastWeeksServiceDoesNotCount() {
        let services = [ServiceStub(date: date(2026, 10, 11), gatheringName: "Sunday worship")]
        let prompt = ServicesLogic.todayPrompt(
            meetings: [sunday], services: services, on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.hasExistingService == false)
    }

    @Test func emptyNameFallsBackToWeekday() {
        let unnamed = ServiceMeetingSnapshot(weekday: 1, hour: 18, minute: 30, name: "  ")
        let prompt = ServicesLogic.todayPrompt(
            meetings: [unnamed], services: [], on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.title == "Today · Sunday 18:30")
    }

    @Test func twoMeetingsPicksFirstWithoutAService() {
        let evening = ServiceMeetingSnapshot(weekday: 1, hour: 18, minute: 0, name: "Evening prayer")
        let services = [ServiceStub(date: date(2026, 10, 18), gatheringName: "Sunday worship")]
        let prompt = ServicesLogic.todayPrompt(
            meetings: [evening, sunday], services: services, on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.name == "Evening prayer")
        #expect(prompt?.hasExistingService == false)
    }

    @Test func twoMeetingsAllRecordedOpensTheEarliest() {
        let evening = ServiceMeetingSnapshot(weekday: 1, hour: 18, minute: 0, name: "Evening prayer")
        let services = [
            ServiceStub(date: date(2026, 10, 18), gatheringName: "Evening prayer"),
            ServiceStub(date: date(2026, 10, 18), gatheringName: "Sunday worship"),
        ]
        let prompt = ServicesLogic.todayPrompt(
            meetings: [evening, sunday], services: services, on: date(2026, 10, 18), calendar: calendar
        )
        #expect(prompt?.name == "Sunday worship")
        #expect(prompt?.existingServiceIndex == 1)
    }

    @Test func freshServiceOpensBothSections() {
        let both = ServicesLogic.initialExpansion(sermonHasContent: false, classHasContent: false)
        #expect(both.sermon && both.bibleClass)
        let onlySermon = ServicesLogic.initialExpansion(sermonHasContent: true, classHasContent: false)
        #expect(onlySermon.sermon && !onlySermon.bibleClass)
        let onlyClass = ServicesLogic.initialExpansion(sermonHasContent: false, classHasContent: true)
        #expect(!onlyClass.sermon && onlyClass.bibleClass)
    }

    @Test func sectionContentRules() {
        #expect(!ServicesLogic.sectionHasContent(texts: ["", "  "], hasNote: false, verseCount: 0))
        #expect(ServicesLogic.sectionHasContent(texts: ["Grace", ""], hasNote: false, verseCount: 0))
        #expect(ServicesLogic.sectionHasContent(texts: [], hasNote: true, verseCount: 0))
        #expect(ServicesLogic.sectionHasContent(texts: [], hasNote: false, verseCount: 2))
    }

    @Test func gatheringToneIsStable() {
        #expect(ServicesLogic.gatheringTone("Sunday worship") == ServicesLogic.gatheringTone(" sunday WORSHIP "))
    }

    @Test func movedIndexStaysInRange() {
        #expect(ServicesLogic.movedIndex(1, by: -1, count: 3) == 0)
        #expect(ServicesLogic.movedIndex(1, by: 1, count: 3) == 2)
        #expect(ServicesLogic.movedIndex(0, by: -1, count: 3) == nil)
        #expect(ServicesLogic.movedIndex(2, by: 1, count: 3) == nil)
    }
}

import Foundation
import Testing
@testable import Selah

struct NotificationPlannerTests {
    private func plan(
        _ id: String = "p1",
        status: ReadingStatus = .reading,
        read: [Int] = [],
        reminders: [ReminderTime] = [ReminderTime(hour: 7, minute: 0)]
    ) -> PlanSnapshot {
        PlanSnapshot(id: id, bookName: "Philippians", status: status, chaptersRead: read, totalChapters: 4, reminders: reminders)
    }

    private func meeting(
        _ id: String = "m1",
        weekday: Int = 1,
        hour: Int = 9,
        minute: Int = 0,
        before: Int? = 30,
        active: Bool = true
    ) -> MeetingSnapshot {
        MeetingSnapshot(id: id, weekday: weekday, hour: hour, minute: minute, name: "Bible study", reminderMinutesBefore: before, isActive: active)
    }

    @Test func readingReminderOnlyWhenReading() {
        #expect(NotificationPlanner.plan(plans: [plan(status: .reading)], meetings: []).count == 1)
        #expect(NotificationPlanner.plan(plans: [plan(status: .upNext)], meetings: []).isEmpty)
        #expect(NotificationPlanner.plan(plans: [plan(status: .done)], meetings: []).isEmpty)
    }

    @Test func bodyUsesNextUnreadChapter() {
        let result = NotificationPlanner.plan(plans: [plan(read: [1, 2, 4])], meetings: [])
        #expect(result.first?.body == "Time for Philippians 3")
        #expect(result.first?.trigger.hour == 7)
        #expect(result.first?.trigger.minute == 0)
        #expect(result.first?.repeats == true)
    }

    @Test func meetingBeforeSunday() {
        let result = NotificationPlanner.plan(plans: [], meetings: [meeting(weekday: 1, hour: 9, minute: 0, before: 30)])
        #expect(result.first?.trigger.weekday == 1)
        #expect(result.first?.trigger.hour == 8)
        #expect(result.first?.trigger.minute == 30)
        #expect(result.first?.title == "Bible study at 09:00")
        #expect(result.first?.body == "Your notes page is ready.")
    }

    @Test func meetingCrossesMidnight() {
        let tuesday = NotificationPlanner.plan(plans: [], meetings: [meeting(weekday: 3, hour: 0, minute: 15, before: 30)])
        #expect(tuesday.first?.trigger.weekday == 2)
        #expect(tuesday.first?.trigger.hour == 23)
        #expect(tuesday.first?.trigger.minute == 45)

        let sunday = NotificationPlanner.plan(plans: [], meetings: [meeting(weekday: 1, hour: 0, minute: 10, before: 30)])
        #expect(sunday.first?.trigger.weekday == 7)
        #expect(sunday.first?.trigger.hour == 23)
        #expect(sunday.first?.trigger.minute == 40)
    }

    @Test func inactiveOrNoReminderMeetingGivesNothing() {
        #expect(NotificationPlanner.plan(plans: [], meetings: [meeting(active: false)]).isEmpty)
        #expect(NotificationPlanner.plan(plans: [], meetings: [meeting(before: 0)]).isEmpty)
        #expect(NotificationPlanner.plan(plans: [], meetings: [meeting(before: nil)]).isEmpty)
    }

    @Test func identifiersAreStableAndUnique() {
        let plans = [
            plan("a", reminders: [ReminderTime(hour: 7, minute: 5), ReminderTime(hour: 21, minute: 0)]),
            plan("b")
        ]
        let meetings = [meeting("x"), meeting("y", weekday: 4)]
        let first = NotificationPlanner.plan(plans: plans, meetings: meetings)
        let second = NotificationPlanner.plan(plans: plans, meetings: meetings)
        #expect(first.map(\.identifier) == second.map(\.identifier))
        #expect(Set(first.map(\.identifier)).count == first.count)
        #expect(first.map(\.identifier).contains("reading-a-0705"))
        #expect(first.map(\.identifier).contains("reading-a-2100"))
        #expect(first.map(\.identifier).contains("meeting-x"))
    }
}

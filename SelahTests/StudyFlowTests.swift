import Foundation
import SwiftData
import Testing
@testable import Selah

@MainActor
struct StudyFlowTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    private func allPlans(_ context: ModelContext) throws -> [ReadingPlan] {
        try context.fetch(FetchDescriptor<ReadingPlan>())
    }

    @Test func addPlanStartingToday() throws {
        let context = try makeContext()
        let now = Date(timeIntervalSince1970: 1_000_000)
        let plan = try #require(
            StudyActions.addPlan(
                bookName: "Philippians",
                length: .fourteenDays,
                startNow: true,
                reminderTime: (hour: 7, minute: 30),
                now: now,
                in: context
            )
        )
        #expect(plan.status == .reading)
        #expect(plan.startDate == now)
        #expect(plan.totalChapters == 4)
        #expect(plan.plannedDays == 14)
        #expect(plan.reminders.count == 1)
        #expect(plan.reminders.first?.hour == 7)
        #expect(plan.reminders.first?.minute == 30)
    }

    @Test func addPlanToUpNextHasNoStartDate() throws {
        let context = try makeContext()
        let plan = try #require(
            StudyActions.addPlan(bookName: "James", length: .oneChapterADay, startNow: false, in: context)
        )
        #expect(plan.status == .upNext)
        #expect(plan.startDate == nil)
        #expect(plan.totalChapters == 5)
        #expect(plan.plannedDays == 5)
        #expect(plan.reminders.isEmpty)
    }

    @Test func duplicateActiveBookIsRejected() throws {
        let context = try makeContext()
        #expect(StudyActions.addPlan(bookName: "Ruth", length: .sevenDays, startNow: false, in: context) != nil)
        #expect(StudyActions.addPlan(bookName: "Ruth", length: .thirtyDays, startNow: true, in: context) == nil)
        #expect(try allPlans(context).count == 1)
    }

    @Test func finishedBookCanBeAddedAgain() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Jude", length: .sevenDays, startNow: true, in: context))
        StudyActions.toggleChapter(1, in: plan)
        #expect(plan.status == .done)
        #expect(StudyActions.addPlan(bookName: "Jude", length: .sevenDays, startNow: true, in: context) != nil)
        #expect(try allPlans(context).count == 2)
    }

    @Test func unknownBookIsRejected() throws {
        let context = try makeContext()
        #expect(StudyActions.addPlan(bookName: "Not a book", length: .sevenDays, startNow: true, in: context) == nil)
    }

    @Test func markingLastChapterMovesToDoneAndUnmarkingMovesBack() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", length: .sevenDays, startNow: true, in: context))
        for chapter in 1...3 { StudyActions.toggleChapter(chapter, in: plan) }
        #expect(plan.status == .reading)

        StudyActions.toggleChapter(4, in: plan)
        #expect(plan.status == .done)
        #expect(plan.finishedDate != nil)

        StudyActions.toggleChapter(4, in: plan)
        #expect(plan.status == .reading)
        #expect(plan.finishedDate == nil)
        #expect(plan.chaptersRead == [1, 2, 3])
    }

    @Test func firstChapterMovesUpNextToReading() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "James", length: .fourteenDays, startNow: false, in: context))
        StudyActions.toggleChapter(1, in: plan)
        #expect(plan.status == .reading)
        #expect(plan.startDate != nil)
    }

    @Test func newEntryIsAttachedAndMarksChapterRead() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", length: .sevenDays, startNow: true, in: context))
        let entry = StudyEntry(date: Date(), chapter: StudyActions.nextChapter(in: plan))
        #expect(entry.chapter == 1)

        StudyActions.saveNewEntry(entry, to: plan, markRead: true, in: context)
        #expect(plan.entries.count == 1)
        #expect(entry.plan === plan)
        #expect(plan.chaptersRead == [1])
        #expect(StudyActions.nextChapter(in: plan) == 2)
    }

    @Test func newEntryWithoutMarkReadLeavesChaptersAlone() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", length: .sevenDays, startNow: true, in: context))
        let entry = StudyEntry(date: Date(), chapter: 2)
        StudyActions.saveNewEntry(entry, to: plan, markRead: false, in: context)
        #expect(plan.entries.count == 1)
        #expect(plan.chaptersRead.isEmpty)
    }

    @Test func remindersAreNotDuplicated() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", length: .sevenDays, startNow: true, in: context))
        #expect(StudyActions.addReminder(to: plan, hour: 6, minute: 0, in: context) != nil)
        #expect(StudyActions.addReminder(to: plan, hour: 6, minute: 0, in: context) == nil)
        #expect(plan.reminders.count == 1)
        let reminder = try #require(plan.reminders.first)
        StudyActions.deleteReminder(reminder, in: context)
        #expect(try context.fetch(FetchDescriptor<ReadingReminder>()).isEmpty)
    }

    @Test func planLineUsesPace() throws {
        let context = try makeContext()
        let start = Date(timeIntervalSince1970: 1_000_000)
        let plan = try #require(
            StudyActions.addPlan(bookName: "Philippians", length: .fourteenDays, startNow: true, now: start, in: context)
        )
        let threeDaysLater = Calendar.current.date(byAdding: .day, value: 2, to: start) ?? start
        #expect(StudyActions.planLine(for: plan, now: threeDaysLater) == "Day 3 of 14 · 1 chapter a day")
    }
}

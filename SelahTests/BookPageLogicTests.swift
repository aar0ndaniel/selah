import Foundation
import SwiftData
import Testing
@testable import Selah

@MainActor
struct BookPageLogicTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func addPlanAcceptsAnyNumberOfDaysAndATone() throws {
        let context = try makeContext()
        let plan = try #require(
            StudyActions.addPlan(bookName: "Psalms", days: 120, startNow: true, tone: .sky, in: context)
        )
        #expect(plan.plannedDays == 120)
        #expect(plan.tone == .sky)
        #expect(plan.cardTone == .sky)
        #expect(plan.reminders.isEmpty)
    }

    @Test func daysAreClampedToOneThrough365() throws {
        #expect(StudyActions.clampedDays(0) == 1)
        #expect(StudyActions.clampedDays(-4) == 1)
        #expect(StudyActions.clampedDays(30) == 30)
        #expect(StudyActions.clampedDays(9_999) == 365)
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", days: 1_000, startNow: false, in: context))
        #expect(plan.plannedDays == 365)
    }

    @Test func defaultToneIsSageAndUnknownRawFallsBack() {
        let plan = ReadingPlan(bookName: "Ruth")
        #expect(plan.tone == .sage)
        plan.toneRaw = "not-a-colour"
        #expect(plan.tone == .sage)
        plan.tone = .rose
        #expect(plan.toneRaw == "rose")
    }

    @Test func entryOnADayFindsNotesAtAnyTime() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", days: 4, startNow: true, in: context))
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: Date())
        let evening = calendar.date(byAdding: .hour, value: 20, to: day) ?? day
        let entry = StudyEntry(date: evening, chapter: 1)
        StudyActions.saveNewEntry(entry, to: plan, markRead: false, in: context)

        #expect(StudyActions.entry(on: day, in: plan) === entry)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: day) ?? day
        #expect(StudyActions.entry(on: yesterday, in: plan) == nil)
    }

    @Test func firstLineSkipsBlankLinesAndHandlesEmptyNotes() {
        #expect(StudyActions.firstLine(of: AttributedString("")) == "")
        #expect(StudyActions.firstLine(of: AttributedString("\n  \nGod keeps his word\nSecond line")) == "God keeps his word")
        #expect(StudyActions.firstLine(of: AttributedString("One line")) == "One line")
    }

    @Test func backupKeepsBannerAndToneAndOldBackupsStillRestore() throws {
        let context = try makeContext()
        let plan = try #require(StudyActions.addPlan(bookName: "Ruth", days: 4, startNow: true, tone: .rose, in: context))
        plan.bannerData = Data([0xFF, 0xD8, 0xFF, 0xD9])

        let backup = try BackupService.makeBackup(from: context)
        let restored = try makeContext()
        _ = try BackupService.restore(try BackupService.decode(BackupService.encode(backup)), into: restored)
        let plans = try restored.fetch(FetchDescriptor<ReadingPlan>())
        #expect(plans.count == 1)
        #expect(plans.first?.tone == .rose)
        #expect(plans.first?.bannerData == Data([0xFF, 0xD8, 0xFF, 0xD9]))

        // A Round 1 plan has neither field.
        var old = backup
        old.plans[0].bannerData = nil
        old.plans[0].toneRaw = nil
        let again = try makeContext()
        _ = try BackupService.restore(old, into: again)
        let oldPlan = try #require(try again.fetch(FetchDescriptor<ReadingPlan>()).first)
        #expect(oldPlan.tone == .sage)
        #expect(oldPlan.bannerData == nil)
    }
}

import Foundation
import SwiftData
import Testing
@testable import Selah

struct ReadingProgressTests {
    private func state(read: [Int] = [], status: ReadingStatus = .upNext, total: Int = 4) -> ReadingState {
        ReadingState(status: status, chaptersRead: read, totalChapters: total, startDate: nil, finishedDate: nil)
    }

    @Test func firstChapterMovesUpNextToReading() {
        var s = state()
        let now = Date(timeIntervalSince1970: 1_000_000)
        s.setChapter(1, read: true, now: now)
        #expect(s.status == .reading)
        #expect(s.startDate == now)
        #expect(s.chaptersRead == [1])
    }

    @Test func lastChapterMovesReadingToDone() {
        var s = state(read: [1, 2, 3], status: .reading)
        let now = Date(timeIntervalSince1970: 2_000_000)
        s.setChapter(4, read: true, now: now)
        #expect(s.status == .done)
        #expect(s.finishedDate == now)
    }

    @Test func unmarkingMovesDoneBackToReading() {
        var s = state(read: [1, 2, 3, 4], status: .done)
        s.finishedDate = Date(timeIntervalSince1970: 3_000_000)
        s.setChapter(2, read: false)
        #expect(s.status == .reading)
        #expect(s.finishedDate == nil)
        #expect(s.chaptersRead == [1, 3, 4])
    }

    @Test func paceRoundsUp() {
        let pace = ReadingProgress.pace(remainingChapters: 10, plannedDays: 5, daysElapsed: 2)
        #expect(pace.remainingDays == 3)
        #expect(pace.chaptersPerDay == 4)
        #expect(pace.dayNumber == 3)
    }

    @Test func paceWithNoDaysLeftUsesOneDay() {
        let zero = ReadingProgress.pace(remainingChapters: 3, plannedDays: 7, daysElapsed: 7)
        #expect(zero.remainingDays == 1)
        #expect(zero.chaptersPerDay == 3)

        let negative = ReadingProgress.pace(remainingChapters: 2, plannedDays: 7, daysElapsed: 10)
        #expect(negative.remainingDays == 1)
        #expect(negative.chaptersPerDay == 2)
        #expect(negative.dayNumber == 7)
    }

    @Test func paceIsAtLeastOneChapterPerDay() {
        let pace = ReadingProgress.pace(remainingChapters: 0, plannedDays: 4, daysElapsed: 1)
        #expect(pace.chaptersPerDay == 1)
    }

    @MainActor
    @Test func sampleDataHasThreeReadingPlans() throws {
        let plans = try SampleData.container.mainContext.fetch(FetchDescriptor<ReadingPlan>())
        #expect(plans.count == 3)
    }

    @MainActor
    @Test func richTextRoundTripKeepsHighlightID() throws {
        var text = AttributedString("Hello world")
        if let range = text.range(of: "world") {
            text[range][HighlightIDAttribute.self] = "abc"
        }
        let entry = StudyEntry(note: text)
        let decoded = entry.note
        #expect(String(decoded.characters) == "Hello world")
        let ids = decoded.runs.compactMap { $0[HighlightIDAttribute.self] }
        #expect(ids == ["abc"])
    }
}

import Foundation
import Testing
@testable import Selah

struct MonthlySummaryTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    private func summary(_ services: [ServiceSnapshot], month: Date? = nil) -> MonthlySummary {
        MonthlySummary(services: services, month: month ?? date(2026, 10, 1), calendar: calendar)
    }

    @Test func countsServicesSermonsClassesAndSongs() {
        let services = [
            ServiceSnapshot(
                date: date(2026, 10, 4), gatheringName: "Sunday worship",
                sermonTitle: "Grace", sermonist: "Pastor A",
                songs: [SongSnapshot(hymnNumber: "12", title: "A"), SongSnapshot(hymnNumber: "30", title: "B")]
            ),
            ServiceSnapshot(
                date: date(2026, 10, 6), gatheringName: "Bible study",
                classLesson: "Ruth", classTeacher: "Sister B",
                songs: [SongSnapshot(hymnNumber: "7", title: "C")]
            ),
            ServiceSnapshot(date: date(2026, 10, 9), gatheringName: "Prayer meeting"),
            ServiceSnapshot(date: date(2026, 9, 27), sermonTitle: "Other month", sermonist: "X")
        ]
        let s = summary(services)
        #expect(s.serviceCount == 3)
        #expect(s.sermonCount == 1)
        #expect(s.classCount == 1)
        #expect(s.songCount == 3)
        #expect(s.sermons.map { $0.title } == ["Grace"])
        #expect(s.classes.map { $0.lesson } == ["Ruth"])
        #expect(!s.isEmpty)
    }

    @Test func sermonCountsWithOnlyASermonist() {
        let s = summary([ServiceSnapshot(date: date(2026, 10, 4), sermonist: "Pastor A")])
        #expect(s.sermonCount == 1)
        #expect(s.classCount == 0)
    }

    @Test func booksAreRankedByCount() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), verseBooks: ["John", "Romans", "John"]),
            ServiceSnapshot(date: date(2026, 10, 11), verseBooks: ["John", "Psalms", "Romans"])
        ]
        let s = summary(services)
        #expect(s.booksQuoted == [
            MonthlySummary.BookCount(book: "John", count: 3),
            MonthlySummary.BookCount(book: "Romans", count: 2),
            MonthlySummary.BookCount(book: "Psalms", count: 1)
        ])
    }

    @Test func bookTiesFollowBibleOrder() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), verseBooks: ["Romans", "Genesis", "John"])
        ]
        let s = summary(services)
        #expect(s.booksQuoted.map { $0.book } == ["Genesis", "John", "Romans"])
    }

    @Test func booksAreLimitedToTopFive() {
        let books = ["Genesis", "Exodus", "Ruth", "Psalms", "John", "Romans", "Jude"]
        let s = summary([ServiceSnapshot(date: date(2026, 10, 4), verseBooks: books)])
        #expect(s.booksQuoted.count == 5)
        #expect(s.booksQuoted.map { $0.book } == ["Genesis", "Exodus", "Ruth", "Psalms", "John"])
    }

    @Test func booksOutsideTheMonthAreIgnored() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), verseBooks: ["John"]),
            ServiceSnapshot(date: date(2026, 11, 1), verseBooks: ["Romans", "Romans"])
        ]
        #expect(summary(services).booksQuoted.map { $0.book } == ["John"])
    }

    @Test func songsAreCountedAcrossServicesByHymnNumber() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), songs: [
                SongSnapshot(hymnNumber: "12", title: "Amazing Grace"),
                SongSnapshot(hymnNumber: "30", title: "Be Thou My Vision")
            ]),
            ServiceSnapshot(date: date(2026, 10, 11), songs: [
                SongSnapshot(hymnNumber: "12", title: ""),
                SongSnapshot(hymnNumber: " 12 ", title: "Amazing Grace")
            ])
        ]
        let s = summary(services)
        #expect(s.songCount == 4)
        #expect(s.songsSung.first == MonthlySummary.SongCount(hymnNumber: "12", title: "Amazing Grace", count: 3))
        #expect(s.songsSung.count == 2)
    }

    @Test func songsWithoutNumbersCountByTitle() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), songs: [SongSnapshot(title: "How Great")]),
            ServiceSnapshot(date: date(2026, 10, 11), songs: [SongSnapshot(title: "how great"), SongSnapshot()])
        ]
        let s = summary(services)
        #expect(s.songCount == 2)
        #expect(s.songsSung.count == 1)
        #expect(s.songsSung[0].count == 2)
    }

    @Test func songTiesSortByHymnNumber() {
        let services = [
            ServiceSnapshot(date: date(2026, 10, 4), songs: [
                SongSnapshot(hymnNumber: "100", title: "C"),
                SongSnapshot(hymnNumber: "9", title: "A")
            ])
        ]
        #expect(summary(services).songsSung.map { $0.hymnNumber } == ["9", "100"])
    }

    @Test func emptyMonthIsEmpty() {
        let s = summary([ServiceSnapshot(date: date(2026, 9, 1), sermonTitle: "Old")], month: date(2026, 10, 1))
        #expect(s.isEmpty)
        #expect(s.serviceCount == 0)
        #expect(s.sermonCount == 0)
        #expect(s.classCount == 0)
        #expect(s.songCount == 0)
        #expect(s.booksQuoted.isEmpty)
        #expect(s.songsSung.isEmpty)
        #expect(summary([]).isEmpty)
    }

    @Test func monthStartIsFirstOfTheMonth() {
        let start = MonthlySummary.monthStart(for: date(2026, 10, 18), calendar: calendar)
        #expect(calendar.component(.day, from: start) == 1)
        #expect(calendar.component(.month, from: start) == 10)
    }
}

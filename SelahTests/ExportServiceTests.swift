import Foundation
import Testing
@testable import Selah

struct ExportServiceTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC") ?? .current
        return c
    }

    private let locale = Locale(identifier: "en_US")

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    @Test func monthlyTextListsCountsSermonsClassesBooksAndSongs() {
        let snapshots = [
            ServiceSnapshot(
                date: date(2026, 10, 4),
                sermonTitle: "Walking in faith",
                sermonist: "Elder Mensah",
                classLesson: "Prayer",
                classTeacher: "Sis Ama",
                verseBooks: ["Hebrews", "Hebrews", "James"],
                songs: [SongSnapshot(hymnNumber: "12", title: "Great is thy faithfulness")]
            ),
            ServiceSnapshot(date: date(2026, 10, 11), verseBooks: ["Hebrews"], songs: [SongSnapshot(hymnNumber: "12", title: "")])
        ]
        let summary = MonthlySummary(services: snapshots, month: date(2026, 10, 1), calendar: calendar)
        let items = [
            ServiceExportItem(
                date: date(2026, 10, 4),
                sermonTitle: "Walking in faith",
                sermonist: "Elder Mensah",
                classLesson: "Prayer",
                classTeacher: "Sis Ama",
                sermonVerses: ["Hebrews 11:1", "James 2:17"],
                classVerses: ["Matthew 6:9"]
            ),
            ServiceExportItem(date: date(2026, 9, 27), sermonTitle: "Other month", sermonist: "Someone")
        ]

        let text = ExportService.monthlyText(summary: summary, services: items, calendar: calendar, locale: locale)

        #expect(text.hasPrefix("Selah — October 2026"))
        #expect(text.contains("2 services"))
        #expect(text.contains("1 sermon"))
        #expect(text.contains("1 Bible class"))
        #expect(text.contains("2 songs"))
        #expect(text.contains("Walking in faith — Elder Mensah"))
        #expect(text.contains("Verses: Hebrews 11:1; James 2:17"))
        #expect(text.contains("Prayer — taught by Sis Ama"))
        #expect(text.contains("Hebrews (3 times)"))
        #expect(text.contains("Hymn 12, Great is thy faithfulness (2 times)"))
        #expect(!text.contains("Other month"))
    }

    @Test func bookTextHasEntriesVerseNoteAndHighlights() {
        let book = BookExportItem(
            bookName: "Philippians",
            totalChapters: 4,
            entries: [
                EntryExportItem(
                    date: date(2026, 10, 6),
                    chapter: 2,
                    note: "Second entry."
                ),
                EntryExportItem(
                    date: date(2026, 10, 5),
                    chapter: 1,
                    verseReference: "Philippians 1:6",
                    verseText: "He which hath begun a good work in you will perform it.",
                    note: "God finishes what he starts.",
                    comments: [CommentExportItem(quote: "good work", comment: "He is faithful")]
                )
            ]
        )

        let text = ExportService.bookText(book, calendar: calendar, locale: locale)

        #expect(text.hasPrefix("Philippians — 4 chapters"))
        #expect(text.contains("Chapter 1"))
        #expect(text.contains("Best verse: Philippians 1:6"))
        #expect(text.contains("He which hath begun a good work"))
        #expect(text.contains("What I learnt"))
        #expect(text.contains("God finishes what he starts."))
        #expect(text.contains("> good work — He is faithful"))
        // Oldest entry first.
        let first = text.range(of: "God finishes")?.lowerBound
        let second = text.range(of: "Second entry.")?.lowerBound
        #expect(first != nil && second != nil && first! < second!)
    }

    @Test func singleChapterBookUsesSingular() {
        let text = ExportService.bookText(BookExportItem(bookName: "Jude", totalChapters: 1), calendar: calendar, locale: locale)
        #expect(text.hasPrefix("Jude — 1 chapter\n"))
        #expect(text.contains("No entries yet."))
    }

    @Test func highlightTextHandlesMissingComment() {
        #expect(ExportDocument.highlightText(quote: "a", comment: "b") == "> a — b")
        #expect(ExportDocument.highlightText(quote: "a", comment: " ") == "> a")
    }

    @Test func fileNamesAreClearAndSafe() {
        let summary = MonthlySummary(services: [], month: date(2026, 10, 1), calendar: calendar)
        #expect(
            ExportService.monthlyFileName(summary: summary, calendar: calendar, locale: locale, ext: "pdf")
                == "Selah October 2026 summary.pdf"
        )
        #expect(ExportService.bookFileName("Song of Solomon", ext: "pdf") == "Selah Song of Solomon entries.pdf")
        #expect(ExportService.sanitised("a/b:c.pdf") == "a-b-c.pdf")
    }

    @MainActor
    @Test func pdfIsWritten() throws {
        let document = ExportService.bookDocument(
            BookExportItem(
                bookName: "Philippians",
                totalChapters: 4,
                entries: [EntryExportItem(date: date(2026, 10, 5), chapter: 1, note: "A short note.")]
            ),
            calendar: calendar,
            locale: locale
        )
        let url = try ExportService.writePDF(document, fileName: "Selah test entries.pdf")
        let data = try Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        #expect(data.starts(with: Array("%PDF".utf8)))
    }
}

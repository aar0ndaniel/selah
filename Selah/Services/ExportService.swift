import SwiftUI
import UIKit

// MARK: - Value snapshots (no SwiftData objects, so the builders are easy to test)

/// One service, copied out of SwiftData, with the verses grouped by part.
struct ServiceExportItem: Sendable, Equatable {
    var date: Date
    var sermonTitle: String
    var sermonist: String
    var classLesson: String
    var classTeacher: String
    var sermonVerses: [String]
    var classVerses: [String]

    init(
        date: Date,
        sermonTitle: String = "",
        sermonist: String = "",
        classLesson: String = "",
        classTeacher: String = "",
        sermonVerses: [String] = [],
        classVerses: [String] = []
    ) {
        self.date = date
        self.sermonTitle = sermonTitle
        self.sermonist = sermonist
        self.classLesson = classLesson
        self.classTeacher = classTeacher
        self.sermonVerses = sermonVerses
        self.classVerses = classVerses
    }

    var hasSermon: Bool { !sermonTitle.exportTrimmed.isEmpty || !sermonist.exportTrimmed.isEmpty }
    var hasClass: Bool { !classLesson.exportTrimmed.isEmpty || !classTeacher.exportTrimmed.isEmpty }
}

/// A highlighted passage and the comment written on it.
struct CommentExportItem: Sendable, Equatable {
    var quote: String
    var comment: String

    init(quote: String = "", comment: String = "") {
        self.quote = quote
        self.comment = comment
    }
}

/// One daily entry of a book.
struct EntryExportItem: Sendable, Equatable {
    var date: Date
    var chapter: Int
    var verseReference: String
    var verseText: String
    /// "What I learnt" as plain text.
    var note: String
    var comments: [CommentExportItem]

    init(
        date: Date,
        chapter: Int,
        verseReference: String = "",
        verseText: String = "",
        note: String = "",
        comments: [CommentExportItem] = []
    ) {
        self.date = date
        self.chapter = chapter
        self.verseReference = verseReference
        self.verseText = verseText
        self.note = note
        self.comments = comments
    }
}

/// A book and its entries.
struct BookExportItem: Sendable, Equatable {
    var bookName: String
    var totalChapters: Int
    var entries: [EntryExportItem]

    init(bookName: String, totalChapters: Int, entries: [EntryExportItem] = []) {
        self.bookName = bookName
        self.totalChapters = totalChapters
        self.entries = entries
    }
}

extension ServiceExportItem {
    @MainActor
    init(_ service: Service) {
        self.init(
            date: service.date,
            sermonTitle: service.sermonTitle,
            sermonist: service.sermonist,
            classLesson: service.classLesson,
            classTeacher: service.classTeacher,
            sermonVerses: service.verses.filter { $0.part == .sermon }.map { $0.reference },
            classVerses: service.verses.filter { $0.part == .bibleClass }.map { $0.reference }
        )
    }
}

extension BookExportItem {
    @MainActor
    init(_ plan: ReadingPlan) {
        let entries = plan.entries
            .sorted { $0.date < $1.date }
            .map { entry in
                EntryExportItem(
                    date: entry.date,
                    chapter: entry.chapter,
                    verseReference: entry.bestVerse?.reference ?? "",
                    verseText: entry.bestVerse?.textSnapshot ?? "",
                    note: String(entry.note.characters),
                    comments: entry.comments
                        .sorted { $0.createdAt < $1.createdAt }
                        .map { CommentExportItem(quote: $0.quotedText, comment: $0.comment) }
                )
            }
        self.init(bookName: plan.bookName, totalChapters: plan.totalChapters, entries: entries)
    }
}

// MARK: - Document

/// What gets exported, as simple blocks. The same blocks make the plain text and the PDF.
struct ExportDocument: Sendable, Equatable {
    enum Block: Sendable, Equatable {
        case title(String)
        case heading(String)
        case label(String)
        case body(String)
        case highlight(quote: String, comment: String)
        case gap
    }

    var blocks: [Block]

    var plainText: String {
        var lines: [String] = []
        for block in blocks {
            switch block {
            case .title(let text), .body(let text), .label(let text):
                lines.append(text)
            case .heading(let text):
                if !lines.isEmpty { lines.append("") }
                lines.append(text)
            case .highlight(let quote, let comment):
                lines.append(ExportDocument.highlightText(quote: quote, comment: comment))
            case .gap:
                lines.append("")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// "> quote — comment"
    static func highlightText(quote: String, comment: String) -> String {
        let q = quote.exportTrimmed
        let c = comment.exportTrimmed
        switch (q.isEmpty, c.isEmpty) {
        case (false, false): return "> \(q) — \(c)"
        case (false, true): return "> \(q)"
        default: return "> \(c)"
        }
    }
}

// MARK: - Builders and PDF

enum ExportService {
    // MARK: Plain text and document builders

    static func monthTitle(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
        return formatter.string(from: date)
    }

    static func dayText(_ date: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: date)
    }

    private static func fullDateText(_ date: Date, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return formatter.string(from: date)
    }

    private static func count(_ n: Int, _ singular: String, _ plural: String) -> String {
        "\(n) \(n == 1 ? singular : plural)"
    }

    private static func songLine(_ item: MonthlySummary.SongCount) -> String {
        let name: String
        switch (item.hymnNumber.isEmpty, item.title.isEmpty) {
        case (false, false): name = "Hymn \(item.hymnNumber), \(item.title)"
        case (false, true): name = "Hymn \(item.hymnNumber)"
        default: name = item.title
        }
        return "\(name) (\(item.count == 1 ? "1 time" : "\(item.count) times"))"
    }

    /// The monthly summary. `services` supplies the sermon and class details (with verses);
    /// the counts, books and songs come from `summary`.
    static func monthlyDocument(
        summary: MonthlySummary,
        services: [ServiceExportItem],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> ExportDocument {
        var blocks: [ExportDocument.Block] = []
        blocks.append(.title("Selah — \(monthTitle(summary.monthStart, calendar: calendar, locale: locale))"))
        blocks.append(.gap)
        blocks.append(.body(count(summary.serviceCount, "service", "services")))
        blocks.append(.body(count(summary.sermonCount, "sermon", "sermons")))
        blocks.append(.body(count(summary.classCount, "Bible class", "Bible classes")))
        blocks.append(.body(count(summary.songCount, "song", "songs")))

        let inMonth = services
            .filter { calendar.isDate($0.date, equalTo: summary.monthStart, toGranularity: .month) }
            .sorted { $0.date < $1.date }

        let sermons = inMonth.filter { $0.hasSermon }
        if !sermons.isEmpty {
            blocks.append(.heading("Sermons"))
            for item in sermons {
                let title = item.sermonTitle.exportTrimmed.isEmpty ? "Untitled sermon" : item.sermonTitle.exportTrimmed
                var line = title
                if !item.sermonist.exportTrimmed.isEmpty { line += " — \(item.sermonist.exportTrimmed)" }
                blocks.append(.label(line))
                blocks.append(.body(dayText(item.date, calendar: calendar, locale: locale)))
                if !item.sermonVerses.isEmpty {
                    blocks.append(.body("Verses: " + item.sermonVerses.joined(separator: "; ")))
                }
                blocks.append(.gap)
            }
        }

        let classes = inMonth.filter { $0.hasClass }
        if !classes.isEmpty {
            blocks.append(.heading("Bible classes"))
            for item in classes {
                let lesson = item.classLesson.exportTrimmed.isEmpty ? "Bible class" : item.classLesson.exportTrimmed
                var line = lesson
                if !item.classTeacher.exportTrimmed.isEmpty { line += " — taught by \(item.classTeacher.exportTrimmed)" }
                blocks.append(.label(line))
                blocks.append(.body(dayText(item.date, calendar: calendar, locale: locale)))
                if !item.classVerses.isEmpty {
                    blocks.append(.body("Verses: " + item.classVerses.joined(separator: "; ")))
                }
                blocks.append(.gap)
            }
        }

        if !summary.booksQuoted.isEmpty {
            blocks.append(.heading("Books quoted most"))
            for item in summary.booksQuoted {
                blocks.append(.body("\(item.book) (\(item.count == 1 ? "1 time" : "\(item.count) times"))"))
            }
        }

        if !summary.songsSung.isEmpty {
            blocks.append(.heading("Songs sung"))
            for item in summary.songsSung {
                blocks.append(.body(songLine(item)))
            }
        }
        return ExportDocument(blocks: trimmedGaps(blocks))
    }

    static func monthlyText(
        summary: MonthlySummary,
        services: [ServiceExportItem],
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        monthlyDocument(summary: summary, services: services, calendar: calendar, locale: locale).plainText
    }

    /// A book's entries, oldest first.
    static func bookDocument(
        _ book: BookExportItem,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> ExportDocument {
        var blocks: [ExportDocument.Block] = []
        let chapters = count(book.totalChapters, "chapter", "chapters")
        blocks.append(.title("\(book.bookName) — \(chapters)"))
        if book.entries.isEmpty {
            blocks.append(.gap)
            blocks.append(.body("No entries yet."))
        }
        for entry in book.entries.sorted(by: { $0.date < $1.date }) {
            blocks.append(
                .heading("\(fullDateText(entry.date, calendar: calendar, locale: locale)) · Chapter \(entry.chapter)")
            )
            if !entry.verseReference.isEmpty {
                blocks.append(.label("Best verse: \(entry.verseReference)"))
                if !entry.verseText.exportTrimmed.isEmpty {
                    blocks.append(.body(entry.verseText.exportTrimmed))
                }
            }
            let note = entry.note.exportTrimmed
            if !note.isEmpty {
                blocks.append(.label("What I learnt"))
                blocks.append(.body(note))
            }
            for comment in entry.comments where !(comment.quote.exportTrimmed.isEmpty && comment.comment.exportTrimmed.isEmpty) {
                blocks.append(.highlight(quote: comment.quote, comment: comment.comment))
            }
        }
        return ExportDocument(blocks: trimmedGaps(blocks))
    }

    static func bookText(
        _ book: BookExportItem,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> String {
        bookDocument(book, calendar: calendar, locale: locale).plainText
    }

    /// Removes a gap at the very end.
    private static func trimmedGaps(_ blocks: [ExportDocument.Block]) -> [ExportDocument.Block] {
        var result = blocks
        while result.last == .gap { result.removeLast() }
        return result
    }

    // MARK: File names

    static func monthlyFileName(summary: MonthlySummary, calendar: Calendar = .current, locale: Locale = .current, ext: String) -> String {
        sanitised("Selah \(monthTitle(summary.monthStart, calendar: calendar, locale: locale)) summary.\(ext)")
    }

    static func bookFileName(_ bookName: String, ext: String) -> String {
        sanitised("Selah \(bookName) entries.\(ext)")
    }

    static func sanitised(_ name: String) -> String {
        let bad = CharacterSet(charactersIn: "/\\:?*\"<>|")
        return name.components(separatedBy: bad).joined(separator: "-")
    }

    // MARK: PDF

    private static let pageSize = CGSize(width: 595.2, height: 841.8) // A4 in points
    private static let margin: CGFloat = 54

    @MainActor
    private static func attributedString(for document: ExportDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let ink = UIColor.black
        let softInk = UIColor.darkGray

        func add(_ text: String, font: UIFont, color: UIColor, before: CGFloat, after: CGFloat, indent: CGFloat = 0) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = before
            style.paragraphSpacing = after
            style.lineSpacing = 2
            style.firstLineHeadIndent = indent
            style.headIndent = indent
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
            result.append(NSAttributedString(string: text + "\n", attributes: attributes))
        }

        for block in document.blocks {
            switch block {
            case .title(let text):
                add(text, font: .systemFont(ofSize: 26, weight: .bold), color: ink, before: 0, after: 6)
            case .heading(let text):
                add(text, font: .systemFont(ofSize: 17, weight: .semibold), color: ink, before: 16, after: 4)
            case .label(let text):
                add(text, font: .systemFont(ofSize: 12, weight: .semibold), color: softInk, before: 6, after: 1)
            case .body(let text):
                add(text, font: .systemFont(ofSize: 12), color: ink, before: 0, after: 3)
            case .highlight(let quote, let comment):
                add(
                    ExportDocument.highlightText(quote: quote, comment: comment),
                    font: .italicSystemFont(ofSize: 12),
                    color: ink,
                    before: 2,
                    after: 4,
                    indent: 14
                )
            case .gap:
                add("", font: .systemFont(ofSize: 6), color: ink, before: 0, after: 0)
            }
        }
        return result
    }

    /// Draws the document onto A4 pages (black on white, whatever the app's appearance) and returns the PDF bytes.
    @MainActor
    static func pdfData(for document: ExportDocument) -> Data {
        let text = attributedString(for: document)
        let contentSize = CGSize(width: pageSize.width - margin * 2, height: pageSize.height - margin * 2)

        let storage = NSTextStorage(attributedString: text)
        let layoutManager = NSLayoutManager()
        storage.addLayoutManager(layoutManager)

        var containers: [NSTextContainer] = []
        repeat {
            let container = NSTextContainer(size: contentSize)
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            layoutManager.ensureLayout(for: container)
            containers.append(container)
        } while NSMaxRange(layoutManager.glyphRange(for: containers[containers.count - 1])) < layoutManager.numberOfGlyphs
            && containers.count < 400

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        return renderer.pdfData { context in
            for container in containers {
                context.beginPage()
                let range = layoutManager.glyphRange(for: container)
                layoutManager.drawGlyphs(forGlyphRange: range, at: CGPoint(x: margin, y: margin))
            }
        }
    }

    /// Writes the PDF to the temporary folder and returns its URL.
    @MainActor
    static func writePDF(_ document: ExportDocument, fileName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(sanitised(fileName))
        try pdfData(for: document).write(to: url, options: .atomic)
        return url
    }
}

extension String {
    var exportTrimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Share sheet UI

/// What the share sheet is showing.
struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

/// The system share sheet (Messages, Files, AirDrop and so on).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// An "Export" menu with PDF and Plain text. Builds the file on tap, then opens the share sheet.
struct ExportMenu: View {
    let title: String
    /// File name without extension, for example "Selah Philippians entries".
    let baseFileName: String
    let makeDocument: () -> ExportDocument

    @State private var shareItem: ShareItem?
    @State private var isWorking = false
    @State private var showError = false

    var body: some View {
        Menu {
            Button {
                exportPDF()
            } label: {
                Label("PDF", systemImage: "doc.richtext")
            }
            Button {
                exportText()
            } label: {
                Label("Plain text", systemImage: "text.alignleft")
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                if isWorking {
                    ProgressView()
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isWorking ? "Preparing…" : title)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .disabled(isWorking)
        .accessibilityLabel(title)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.items)
                .presentationDetents([.medium, .large])
        }
        .alert("Couldn't export", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Selah couldn't make the file. Please try again.")
        }
    }

    private func exportText() {
        let text = makeDocument().plainText
        shareItem = ShareItem(items: [text])
    }

    private func exportPDF() {
        isWorking = true
        Task { @MainActor in
            // Let the progress indicator appear before the work starts.
            await Task.yield()
            do {
                let url = try ExportService.writePDF(makeDocument(), fileName: baseFileName + ".pdf")
                shareItem = ShareItem(items: [url])
            } catch {
                showError = true
            }
            isWorking = false
        }
    }
}

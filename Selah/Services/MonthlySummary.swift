import Foundation

/// Plain value copy of a song, so the maths needs no SwiftData objects.
struct SongSnapshot: Sendable, Equatable {
    var hymnNumber: String
    var title: String

    init(hymnNumber: String = "", title: String = "") {
        self.hymnNumber = hymnNumber
        self.title = title
    }
}

/// Plain value copy of a service.
struct ServiceSnapshot: Sendable, Equatable {
    var date: Date
    var gatheringName: String
    var sermonTitle: String
    var sermonist: String
    var classLesson: String
    var classTeacher: String
    /// The `book` of every verse attached to the service (sermon and class).
    var verseBooks: [String]
    var songs: [SongSnapshot]

    init(
        date: Date,
        gatheringName: String = "",
        sermonTitle: String = "",
        sermonist: String = "",
        classLesson: String = "",
        classTeacher: String = "",
        verseBooks: [String] = [],
        songs: [SongSnapshot] = []
    ) {
        self.date = date
        self.gatheringName = gatheringName
        self.sermonTitle = sermonTitle
        self.sermonist = sermonist
        self.classLesson = classLesson
        self.classTeacher = classTeacher
        self.verseBooks = verseBooks
        self.songs = songs
    }

    /// A sermon was recorded when it has a title or a sermonist.
    var hasSermon: Bool { !sermonTitle.isBlank || !sermonist.isBlank }
    /// A Bible class was recorded when it has a lesson or a teacher.
    var hasClass: Bool { !classLesson.isBlank || !classTeacher.isBlank }
}

/// Everything the Monthly segment shows for one month. Pure maths; unit tested.
struct MonthlySummary: Sendable, Equatable {
    struct SermonItem: Sendable, Equatable {
        var date: Date
        var title: String
        var sermonist: String
    }

    struct ClassItem: Sendable, Equatable {
        var date: Date
        var lesson: String
        var teacher: String
    }

    struct BookCount: Sendable, Equatable {
        var book: String
        var count: Int
    }

    struct SongCount: Sendable, Equatable {
        var hymnNumber: String
        var title: String
        var count: Int
    }

    static let topBooksLimit = 5

    let monthStart: Date
    let serviceCount: Int
    let sermonCount: Int
    let classCount: Int
    /// Total songs sung (a hymn sung twice counts twice).
    let songCount: Int
    let sermons: [SermonItem]
    let classes: [ClassItem]
    let booksQuoted: [BookCount]
    let songsSung: [SongCount]

    var isEmpty: Bool { serviceCount == 0 }

    /// First moment of the month containing `date`.
    static func monthStart(for date: Date, calendar: Calendar = .current) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: parts) ?? date
    }

    init(services: [ServiceSnapshot], month: Date, calendar: Calendar = .current) {
        let start = MonthlySummary.monthStart(for: month, calendar: calendar)
        self.monthStart = start

        let inMonth = services
            .filter { calendar.isDate($0.date, equalTo: start, toGranularity: .month) }
            .sorted { $0.date < $1.date }

        serviceCount = inMonth.count

        let sermonServices = inMonth.filter { $0.hasSermon }
        sermonCount = sermonServices.count
        sermons = sermonServices.map {
            SermonItem(date: $0.date, title: $0.sermonTitle.trimmed, sermonist: $0.sermonist.trimmed)
        }

        let classServices = inMonth.filter { $0.hasClass }
        classCount = classServices.count
        classes = classServices.map {
            ClassItem(date: $0.date, lesson: $0.classLesson.trimmed, teacher: $0.classTeacher.trimmed)
        }

        // Books quoted: one count per attached verse, ranked high to low.
        // Ties keep Bible order (Genesis first); unknown names go last, A to Z.
        var bookTotals: [String: Int] = [:]
        for service in inMonth {
            for book in service.verseBooks {
                let name = book.trimmed
                if !name.isEmpty { bookTotals[name, default: 0] += 1 }
            }
        }
        let ranked = bookTotals
            .map { BookCount(book: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let l = BibleBooks.names.firstIndex(of: lhs.book) ?? Int.max
                let r = BibleBooks.names.firstIndex(of: rhs.book) ?? Int.max
                if l != r { return l < r }
                return lhs.book < rhs.book
            }
        booksQuoted = Array(ranked.prefix(MonthlySummary.topBooksLimit))

        // Songs: the same hymn number counts together; with no number, the title is the key.
        var numbers: [String: String] = [:]
        var titles: [String: String] = [:]
        var counts: [String: Int] = [:]
        var total = 0
        for service in inMonth {
            for song in service.songs {
                let number = song.hymnNumber.trimmed
                let title = song.title.trimmed
                if number.isEmpty && title.isEmpty { continue }
                total += 1
                let key = number.isEmpty ? "t:" + title.lowercased() : "n:" + number.lowercased()
                counts[key, default: 0] += 1
                numbers[key] = number
                if (titles[key] ?? "").isEmpty { titles[key] = title }
            }
        }
        songCount = total
        songsSung = counts
            .map { SongCount(hymnNumber: numbers[$0.key] ?? "", title: titles[$0.key] ?? "", count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count > rhs.count }
                let l = Int(lhs.hymnNumber) ?? Int.max
                let r = Int(rhs.hymnNumber) ?? Int.max
                if l != r { return l < r }
                if lhs.hymnNumber != rhs.hymnNumber { return lhs.hymnNumber < rhs.hymnNumber }
                return lhs.title < rhs.title
            }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var isBlank: Bool { trimmed.isEmpty }
}

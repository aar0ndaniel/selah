import Foundation

// What the home screen widgets show. The app writes one snapshot to the shared app group container whenever it
// opens or goes to the background; the widget extension only reads it. This file is compiled into both targets, so it
// stays plain Foundation (no SwiftData, no SwiftUI).
//
// The snapshot holds a week of days ahead (streak counts and verses worked out by the app for each day, as if nothing
// more is logged), so the widgets stay right after midnight even when the app isn't opened.

/// One day of the streak, as the app worked it out for that date.
struct WidgetStreakDay: Codable, Equatable, Sendable {
    var date: Date
    var current: Int
    var best: Int
    var doneToday: Bool
    /// Monday to Sunday of that date's week.
    var week: [WidgetWeekCell]
}

/// One cell of the M to S row. `state` is "done", "pending", "missed" or "none".
struct WidgetWeekCell: Codable, Equatable, Sendable {
    var date: Date
    var state: String
    var isToday: Bool
}

/// The verse for one day: the one the user chose for today, or a well-loved passage.
struct WidgetVerse: Codable, Equatable, Sendable {
    var date: Date
    var text: String
    /// For example "John 3:16 (KJV)".
    var reference: String
    /// True when the user picked it on Today.
    var chosen: Bool
}

struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// `MascotMode` raw value ("coral", "sky", ...).
    var mascotMode: String = "coral"
    /// "study" or "service": the streak the user shows on Today.
    var streakKind: String = "study"
    var streakDays: [WidgetStreakDay] = []
    var verses: [WidgetVerse] = []
    /// Today's answer to "How are you feeling?", as a `MascotMood` raw value.
    var moodRaw: String?
    var moodDate: Date?
}

// MARK: - What a widget shows on a given date

/// The streak as a widget shows it on one date.
struct WidgetStreakDisplay: Equatable, Sendable {
    var kindTitle: String
    var count: Int
    var best: Int
    var doneToday: Bool
    var week: [WidgetWeekCell]

    /// A streak of 0 shows the grey flame.
    var lit: Bool { count > 0 }
}

enum WidgetDisplay {
    static func streak(in snapshot: WidgetSnapshot?, on date: Date, calendar: Calendar = .current) -> WidgetStreakDisplay? {
        guard let snapshot,
              let day = snapshot.streakDays.first(where: { calendar.isDate($0.date, inSameDayAs: date) })
        else { return nil }
        return WidgetStreakDisplay(
            kindTitle: snapshot.streakKind == "service" ? "Service" : "Study",
            count: day.current,
            best: max(day.best, day.current),
            doneToday: day.doneToday,
            week: day.week
        )
    }

    /// The verse for the date. Falls back to the newest verse before it, so the widget is never empty once the app has
    /// written a snapshot.
    static func verse(in snapshot: WidgetSnapshot?, on date: Date, calendar: Calendar = .current) -> WidgetVerse? {
        guard let snapshot else { return nil }
        if let exact = snapshot.verses.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
            return exact
        }
        return snapshot.verses
            .filter { $0.date <= date }
            .max { $0.date < $1.date }
    }

    /// Today's mood raw value, or nil when the user hasn't answered today.
    static func mood(in snapshot: WidgetSnapshot?, on date: Date, calendar: Calendar = .current) -> String? {
        guard let snapshot, let raw = snapshot.moodRaw, let day = snapshot.moodDate,
              calendar.isDate(day, inSameDayAs: date)
        else { return nil }
        return raw
    }

    /// Midnights after `date` for which the snapshot has a streak day or a verse, for the widget timeline.
    static func refreshDates(in snapshot: WidgetSnapshot?, after date: Date, calendar: Calendar = .current) -> [Date] {
        guard let snapshot else { return [] }
        let days = snapshot.streakDays.map(\.date) + snapshot.verses.map(\.date)
        let starts = Set(days.map { calendar.startOfDay(for: $0) })
        return starts.filter { $0 > date }.sorted()
    }
}

// MARK: - Shared store

/// Reads and writes the snapshot in the app group container. Every call is safe when the app group is missing (for
/// example when a re-signing tool drops it): reads return nil and writes do nothing.
enum WidgetStore {
    static let appGroupID = "group.com.aarondaniel.selah"
    private static let fileName = "widget-snapshot.json"

    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(fileName)
    }

    static func load() -> WidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    @discardableResult
    static func save(_ snapshot: WidgetSnapshot) -> Bool {
        guard let url = fileURL, let data = try? JSONEncoder().encode(snapshot) else { return false }
        do {
            try data.write(to: url, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}

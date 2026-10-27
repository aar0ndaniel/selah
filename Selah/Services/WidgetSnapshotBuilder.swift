import Foundation

/// Builds the home screen widget snapshot from plain values (no SwiftData), so it is unit-testable.
/// `WidgetSync` gathers the values from the store and saves the result.
enum WidgetSnapshotBuilder {
    /// Days covered from today, so the widgets stay right for a week without the app being opened.
    static let daysAhead = 7
    /// Passages longer than this are skipped for the daily fallback verse; they don't fit a widget.
    static let maxPassageLength = 280

    /// A well-loved passage with its text already looked up.
    struct Passage: Equatable, Sendable {
        var text: String
        var reference: String
    }

    static func build(
        input: StreakInput,
        kind: StreakKind,
        mascotMode: MascotMode,
        chosenVerse: Passage?,
        passages: [Passage],
        mood: MascotMood?,
        moodDate: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> WidgetSnapshot {
        // Start of each day, so the snapshot only changes when the data does (the app skips an unchanged write).
        let startOfToday = calendar.startOfDay(for: now)
        let days: [Date] = (0..<daysAhead).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfToday)
        }
        let usable = passages.filter { !$0.text.isEmpty && $0.text.count <= maxPassageLength }

        var snapshot = WidgetSnapshot()
        snapshot.mascotMode = mascotMode.rawValue
        snapshot.streakKind = kind.rawValue
        snapshot.streakDays = days.map { streakDay(input: input, kind: kind, on: $0, calendar: calendar) }
        snapshot.verses = days.enumerated().compactMap { index, date in
            if index == 0, let chosenVerse {
                return WidgetVerse(date: date, text: chosenVerse.text, reference: chosenVerse.reference, chosen: true)
            }
            guard let passage = dailyPassage(usable, on: date, calendar: calendar) else { return nil }
            return WidgetVerse(date: date, text: passage.text, reference: passage.reference, chosen: false)
        }
        if let mood, let moodDate, calendar.isDate(moodDate, inSameDayAs: now) {
            snapshot.moodRaw = mood.rawValue
            snapshot.moodDate = moodDate
        }
        return snapshot
    }

    /// The streak for one date, as if nothing more is logged before then.
    static func streakDay(input: StreakInput, kind: StreakKind, on date: Date, calendar: Calendar = .current) -> WidgetStreakDay {
        let count = kind.count(in: Streaks.summary(input, today: date, calendar: calendar))
        let week = ActivityCalendar.weekStates(input, weekOf: date, today: date, calendar: calendar)
        let states = kind == .study ? week.study : week.service
        let cells = week.days.enumerated().map { index, day in
            WidgetWeekCell(
                date: day,
                state: stateName(states.indices.contains(index) ? states[index] : .none),
                isToday: week.todayIndex == index
            )
        }
        return WidgetStreakDay(
            date: date,
            current: count.current,
            best: max(count.best, count.current),
            doneToday: count.doneToday,
            week: cells
        )
    }

    /// The same passage all day, a different one each day.
    static func dailyPassage(_ passages: [Passage], on date: Date, calendar: Calendar = .current) -> Passage? {
        guard !passages.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return passages[day % passages.count]
    }

    static func stateName(_ state: WeekDayState) -> String {
        switch state {
        case .done: return "done"
        case .pending: return "pending"
        case .missed: return "missed"
        case .none: return "none"
        }
    }
}

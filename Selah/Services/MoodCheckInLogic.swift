import Foundation

/// Rules for the daily "How are you feeling today?" check-in. Plain values, no SwiftData or UI.
enum MoodCheckInLogic {
    /// `@AppStorage` key (a Double, seconds since 1970; 0 = never) for the last time "Not now" was tapped.
    static let skippedKey = "moodCheckInSkippedAt"

    /// True when the check-in should appear: there is no mood entry for today and "Not now" was not tapped today.
    /// The next calendar day it is due again.
    static func isDue(
        entryDates: [Date],
        skippedAt: Date?,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        if entryDates.contains(where: { calendar.isDate($0, inSameDayAs: now) }) { return false }
        if let skippedAt, calendar.isDate(skippedAt, inSameDayAs: now) { return false }
        return true
    }

    /// The stored "Not now" time as a date, or nil when it was never tapped.
    static func skippedDate(from stored: Double) -> Date? {
        stored > 0 ? Date(timeIntervalSince1970: stored) : nil
    }

    /// The line on Today: "Feeling joyful", or "How are you feeling?" when there is no entry today.
    static func todayRowText(for mood: MascotMood?) -> String {
        guard let mood else { return "How are you feeling?" }
        return "Feeling \(mood.title.lowercased())"
    }

    /// "How are you feeling today, Ama?", or without the name when it is empty.
    static func headline(name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "How are you feeling today?" : "How are you feeling today, \(trimmed)?"
    }
}

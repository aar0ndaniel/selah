import Foundation

// Pure rules for Quiet time (no SwiftUI, no SwiftData). Unit tested in QuietTimeLogicTests.
//
// Quiet time = a user-made Focus plus Shortcuts automations, with Selah supplying App Intents, a Focus filter and a
// setup screen (docs/PLAN.md, "Later: quiet time"). Nothing here needs an entitlement.

/// Where Selah opens for a quiet-time intent or a Focus filter.
enum QuietDestination: String, Sendable, Equatable, CaseIterable {
    /// The Today tab.
    case today
    /// Today's study note for the first Reading book (or Study with Add book when there is none).
    case studySession
    /// Today's service page (opened or created).
    case serviceNotes
}

// MARK: - Focus filter sessions

/// What the Focus filter last told us, kept in UserDefaults so it survives the app being relaunched.
struct QuietFocusRecord: Sendable, Equatable {
    var destination: QuietDestination
    /// When the filter was applied.
    var activatedAt: Date
    /// The `activatedAt` value we already navigated for, or nil when we have not navigated yet.
    var handledAt: Date?
}

enum QuietFocusRule {
    /// A filter activation older than this is ignored. iOS also runs the filter when a Focus turns OFF (with no
    /// reliable way to tell the two apart), so a stale record must not pull the user around days later.
    static let maxAge: TimeInterval = 2 * 60 * 60

    /// The destination to open now, or nil. Rule: once per Focus session, and only while the session is fresh.
    /// - A record we already handled (`handledAt == activatedAt`) never opens again, so the user is not yanked
    ///   back every time they return to the app during the same Focus.
    /// - A new activation (a later `activatedAt`) opens once again.
    static func destinationToOpen(
        _ record: QuietFocusRecord?,
        now: Date,
        maxAge: TimeInterval = QuietFocusRule.maxAge
    ) -> QuietDestination? {
        guard let record else { return nil }
        guard record.handledAt != record.activatedAt else { return nil }
        let age = now.timeIntervalSince(record.activatedAt)
        guard age <= maxAge else { return nil }
        return record.destination
    }
}

/// Reads and writes the Focus-filter record. Nonisolated because the filter's `perform()` runs off the main actor.
enum QuietFocusStore {
    private static let destinationKey = "quiet.focus.destination"
    private static let activatedKey = "quiet.focus.activatedAt"
    private static let handledKey = "quiet.focus.handledAt"

    static func recordActivation(
        destination: QuietDestination,
        at date: Date = Date(),
        defaults: UserDefaults = .standard
    ) {
        defaults.set(destination.rawValue, forKey: destinationKey)
        defaults.set(date.timeIntervalSince1970, forKey: activatedKey)
        defaults.removeObject(forKey: handledKey)
    }

    static func load(defaults: UserDefaults = .standard) -> QuietFocusRecord? {
        guard let raw = defaults.string(forKey: destinationKey),
              let destination = QuietDestination(rawValue: raw),
              defaults.object(forKey: activatedKey) != nil
        else { return nil }
        let activated = Date(timeIntervalSince1970: defaults.double(forKey: activatedKey))
        let handled: Date? = defaults.object(forKey: handledKey) == nil
            ? nil
            : Date(timeIntervalSince1970: defaults.double(forKey: handledKey))
        return QuietFocusRecord(destination: destination, activatedAt: activated, handledAt: handled)
    }

    /// Marks this activation as used, so it does not open again.
    static func markHandled(_ record: QuietFocusRecord, defaults: UserDefaults = .standard) {
        defaults.set(record.activatedAt.timeIntervalSince1970, forKey: handledKey)
    }
}

// MARK: - Schedule list for the setup screen

/// A reading reminder as plain values.
struct QuietReadingTime: Sendable, Equatable {
    var bookName: String
    var hour: Int
    var minute: Int
}

/// One line in step 4 of the setup screen: a time at which the user can start an automation.
struct QuietScheduleItem: Sendable, Equatable, Identifiable {
    enum Kind: Sendable, Equatable { case service, study }

    var kind: Kind
    /// 1 = Sunday ... 7 = Saturday, or nil for a daily time.
    var weekday: Int?
    var hour: Int
    var minute: Int
    /// Gathering name ("Bible study") or book name ("Philippians").
    var title: String
    /// "Tuesday" or "Daily", already in plain words.
    var dayText: String

    var id: String { "\(kind)-\(weekday ?? 0)-\(hour)-\(minute)-\(title)" }

    /// "18:30"
    var timeText: String { String(format: "%02d:%02d", hour, minute) }

    /// "Tuesday 18:30"
    var whenText: String { "\(dayText) \(timeText)" }

    /// "Tuesday 18:30 · Bible study"
    var label: String { "\(whenText) · \(title)" }

    /// The Selah action to add to the automation.
    var actionName: String {
        switch kind {
        case .service: return "Start service notes"
        case .study: return "Start study session"
        }
    }
}

enum QuietScheduleBuilder {
    /// Service times first (by weekday, then time), then daily reading times (by time, then book name).
    /// Inactive meeting days are left out, and identical reading times for one book are listed once.
    static func items(
        meetings: [ServiceMeetingSnapshot],
        reading: [QuietReadingTime],
        calendar: Calendar = .current
    ) -> [QuietScheduleItem] {
        let services = meetings
            .filter { $0.isActive }
            .sorted { lhs, rhs in
                if lhs.weekday != rhs.weekday { return lhs.weekday < rhs.weekday }
                if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
                return lhs.minute < rhs.minute
            }
            .map { meeting in
                QuietScheduleItem(
                    kind: .service,
                    weekday: meeting.weekday,
                    hour: meeting.hour,
                    minute: meeting.minute,
                    title: meeting.displayName(calendar: calendar),
                    dayText: weekdayName(meeting.weekday, calendar: calendar)
                )
            }

        var seen = Set<String>()
        let study = reading
            .sorted { lhs, rhs in
                if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
                if lhs.minute != rhs.minute { return lhs.minute < rhs.minute }
                return lhs.bookName.localizedCaseInsensitiveCompare(rhs.bookName) == .orderedAscending
            }
            .map { time -> QuietScheduleItem in
                let trimmed = time.bookName.trimmingCharacters(in: .whitespacesAndNewlines)
                return QuietScheduleItem(
                    kind: .study,
                    weekday: nil,
                    hour: time.hour,
                    minute: time.minute,
                    title: trimmed.isEmpty ? "Reading" : trimmed,
                    dayText: "Daily"
                )
            }
            .filter { seen.insert($0.id).inserted }

        return services + study
    }

    static func weekdayName(_ weekday: Int, calendar: Calendar) -> String {
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }
}

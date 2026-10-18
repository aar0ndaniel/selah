import Foundation

/// Plain value copy of a meeting day, so the "is today a meeting day" rule needs no SwiftData objects.
struct MeetingSnapshot: Sendable, Equatable {
    /// 1 = Sunday ... 7 = Saturday (Calendar weekday).
    var weekday: Int
    var hour: Int
    var minute: Int
    var name: String
    var isActive: Bool

    init(weekday: Int, hour: Int = 9, minute: Int = 0, name: String = "", isActive: Bool = true) {
        self.weekday = weekday
        self.hour = hour
        self.minute = minute
        self.name = name
        self.isActive = isActive
    }

    /// "09:00"
    var timeLabel: String { String(format: "%02d:%02d", hour, minute) }

    /// The name, or the weekday name when the name is empty.
    func displayName(calendar: Calendar = .current) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let symbols = calendar.weekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "" }
        return symbols[weekday - 1]
    }
}

extension MeetingSnapshot {
    @MainActor
    init(_ day: MeetingDay) {
        self.init(
            weekday: day.weekday,
            hour: day.hour,
            minute: day.minute,
            name: day.name,
            isActive: day.isActive
        )
    }
}

/// The date and gathering name of a recorded service.
struct ServiceStub: Sendable, Equatable {
    var date: Date
    var gatheringName: String

    init(date: Date, gatheringName: String = "") {
        self.date = date
        self.gatheringName = gatheringName
    }
}

/// What the card at the top of the Services page offers when today is a meeting day.
struct TodayPrompt: Sendable, Equatable {
    let meeting: MeetingSnapshot
    /// Name of the gathering ("Sunday worship").
    let name: String
    /// Index (into the `services` array that was passed in) of today's service, when one is already recorded.
    let existingServiceIndex: Int?

    var hasExistingService: Bool { existingServiceIndex != nil }

    /// "Today · Sunday worship 09:00"
    var title: String { "Today · \(name) \(meeting.timeLabel)" }

    /// The primary button label.
    var buttonTitle: String {
        hasExistingService ? "Open today's service" : "Add notes for today's service"
    }
}

/// Pure rules for the Services tab. Unit tested.
enum ServicesLogic {
    /// The meeting to offer for `date`, or nil when `date` is not an active meeting day.
    ///
    /// Inactive meeting days never count. When several meetings fall on the day, the earliest one that has no
    /// service recorded yet wins; if all have one, the earliest meeting is shown and the button opens its service.
    /// A recorded service matches a meeting when it is on the same day with the same gathering name.
    static func todayPrompt(
        meetings: [MeetingSnapshot],
        services: [ServiceStub],
        on date: Date,
        calendar: Calendar = .current
    ) -> TodayPrompt? {
        let weekday = calendar.component(.weekday, from: date)
        let candidates = meetings
            .filter { $0.isActive && $0.weekday == weekday }
            .sorted { lhs, rhs in
                if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
                return lhs.minute < rhs.minute
            }
        guard !candidates.isEmpty else { return nil }

        let options = candidates.map { meeting -> TodayPrompt in
            let name = meeting.displayName(calendar: calendar)
            let index = services.firstIndex {
                calendar.isDate($0.date, inSameDayAs: date) && $0.gatheringName == name
            }
            return TodayPrompt(meeting: meeting, name: name, existingServiceIndex: index)
        }
        return options.first { !$0.hasExistingService } ?? options[0]
    }

    /// Which Sermon and Bible class sections start open.
    /// A section with content opens. A brand-new service (nothing in either) opens both, so there is
    /// somewhere to type.
    static func initialExpansion(sermonHasContent: Bool, classHasContent: Bool) -> (sermon: Bool, bibleClass: Bool) {
        if !sermonHasContent && !classHasContent { return (true, true) }
        return (sermonHasContent, classHasContent)
    }

    /// True when any text is non-blank, or there is a note, or there are verses.
    static func sectionHasContent(texts: [String], hasNote: Bool, verseCount: Int) -> Bool {
        if hasNote || verseCount > 0 { return true }
        return texts.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// A stable tone for a gathering name (so "Sunday worship" is always the same colour).
    /// Not `hashValue`, which changes between launches.
    static func gatheringTone(_ name: String) -> Tone {
        let tones: [Tone] = [.sky, .sage, .coral, .rose, .sand, .teal]
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let seed = key.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 9973 }
        return tones[seed % tones.count]
    }

    /// Moves the item at `index` one place up (`-1`) or down (`+1`); nil when it cannot move.
    static func movedIndex(_ index: Int, by step: Int, count: Int) -> Int? {
        let target = index + step
        guard index >= 0, index < count, target >= 0, target < count else { return nil }
        return target
    }
}

import Foundation

/// Plain value copy of a meeting day, so the "is today a meeting day" rule needs no SwiftData objects.
struct ServiceMeetingSnapshot: Sendable, Equatable {
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

extension ServiceMeetingSnapshot {
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
    let meeting: ServiceMeetingSnapshot
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
        meetings: [ServiceMeetingSnapshot],
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

// MARK: - Service parts

/// Plain value copy of a service part (sermon, Bible class or song), so the row and title rules need no SwiftData.
struct ServicePartSummary: Sendable, Equatable {
    var kind: ServicePartKind
    var title: String
    var person: String
    var songType: SongType
    var hymnNumber: String
    var isFavourite: Bool

    init(
        kind: ServicePartKind,
        title: String = "",
        person: String = "",
        songType: SongType = .hymn,
        hymnNumber: String = "",
        isFavourite: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.person = person
        self.songType = songType
        self.hymnNumber = hymnNumber
        self.isFavourite = isFavourite
    }

    /// What the part is called in one line: the title, or for a song "Hymn 212, Title".
    var displayTitle: String {
        switch kind {
        case .song:
            return SongLibraryLogic.displayName(type: songType, hymnNumber: hymnNumber, title: title)
        case .sermon, .bibleClass:
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// The headline of a service row and note card.
struct ServiceHeadline: Sendable, Equatable {
    var title: String
    /// Sermonist or teacher of the part the title came from; empty for songs.
    var detail: String
}

extension ServicesLogic {
    /// Row title of a service: the first sermon with a title, else the first part that has a title or hymn number,
    /// else nil (the caller shows the gathering name).
    static func headline(parts: [ServicePartSummary]) -> ServiceHeadline? {
        func trimmed(_ text: String) -> String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let sermon = parts.first(where: { $0.kind == .sermon && !$0.displayTitle.isEmpty }) {
            return ServiceHeadline(title: sermon.displayTitle, detail: trimmed(sermon.person))
        }
        if let part = parts.first(where: { !$0.displayTitle.isEmpty }) {
            return ServiceHeadline(title: part.displayTitle, detail: part.kind == .song ? "" : trimmed(part.person))
        }
        return nil
    }

    /// Whether a part starts open on the service page. Sermons and Bible classes open (that is where notes are
    /// typed); a song opens only while it is still empty, otherwise its one-line summary in the row is enough.
    static func partStartsExpanded(kind: ServicePartKind, hasContent: Bool) -> Bool {
        kind == .song ? !hasContent : true
    }

    /// New `order` values after moving rows, as `List.onMove` reports it. Returns the original indices in the new order.
    static func reorderedIndices(count: Int, from source: IndexSet, to destination: Int) -> [Int] {
        let valid = source.filter { $0 >= 0 && $0 < count }
        let moving = valid.sorted()
        var remaining = (0..<count).filter { !valid.contains($0) }
        let target = min(max(destination, 0), count)
        let insertAt = target - valid.filter { $0 < target }.count
        remaining.insert(contentsOf: moving, at: insertAt)
        return remaining
    }

    /// Heading of a part on the service page: "Sermon", "Bible class", or the song type.
    static func partHeading(kind: ServicePartKind, songType: SongType) -> String {
        switch kind {
        case .sermon: return "Sermon"
        case .bibleClass: return "Bible class"
        case .song: return SongLibraryLogic.typeName(songType)
        }
    }
}

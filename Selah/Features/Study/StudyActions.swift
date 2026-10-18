import Foundation
import SwiftData

/// How long a new reading plan should take.
enum PlanLength: Hashable, CaseIterable, Sendable {
    case sevenDays, fourteenDays, thirtyDays, oneChapterADay

    var title: String {
        switch self {
        case .sevenDays: return "7 days"
        case .fourteenDays: return "14 days"
        case .thirtyDays: return "30 days"
        case .oneChapterADay: return "1 a day"
        }
    }

    func days(chapters: Int) -> Int {
        switch self {
        case .sevenDays: return 7
        case .fourteenDays: return 14
        case .thirtyDays: return 30
        case .oneChapterADay: return max(chapters, 1)
        }
    }
}

/// Non-UI logic for the Study tab. Views call these so the rules can be unit tested.
@MainActor
enum StudyActions {
    /// A book counts as active while it is Up next or Reading.
    static func hasActivePlan(book: String, in plans: [ReadingPlan]) -> Bool {
        plans.contains { $0.bookName == book && $0.status != .done }
    }

    static func status(of book: String, in plans: [ReadingPlan]) -> ReadingStatus? {
        plans.first { $0.bookName == book && $0.status != .done }?.status
    }

    /// Adds a plan for a book. Returns nil when the book already has an active plan
    /// or the name is not one of the 66 books.
    @discardableResult
    static func addPlan(
        bookName: String,
        length: PlanLength,
        startNow: Bool,
        reminderTime: (hour: Int, minute: Int)? = nil,
        now: Date = Date(),
        in context: ModelContext
    ) -> ReadingPlan? {
        guard let index = BibleBooks.names.firstIndex(of: bookName) else { return nil }
        let days = length.days(chapters: BibleBooks.chapterCounts[index])
        return addPlan(
            bookName: bookName,
            days: days,
            startNow: startNow,
            reminderTime: reminderTime,
            now: now,
            in: context
        )
    }

    /// Adds a plan with any number of days (clamped to 1...365) and an optional card colour.
    /// Returns nil when the book already has an active plan or the name is not one of the 66 books.
    @discardableResult
    static func addPlan(
        bookName: String,
        days: Int,
        startNow: Bool,
        tone: NoteColour? = nil,
        reminderTime: (hour: Int, minute: Int)? = nil,
        now: Date = Date(),
        in context: ModelContext
    ) -> ReadingPlan? {
        guard let index = BibleBooks.names.firstIndex(of: bookName) else { return nil }
        let existing = (try? context.fetch(FetchDescriptor<ReadingPlan>())) ?? []
        guard !hasActivePlan(book: bookName, in: existing) else { return nil }

        let chapters = BibleBooks.chapterCounts[index]
        let plan = ReadingPlan(
            bookName: bookName,
            totalChapters: chapters,
            status: startNow ? .reading : .upNext,
            plannedDays: clampedDays(days),
            startDate: startNow ? now : nil
        )
        if let tone { plan.tone = tone }
        context.insert(plan)
        if let reminderTime {
            addReminder(to: plan, hour: reminderTime.hour, minute: reminderTime.minute, in: context)
        }
        NotificationScheduler.shared.reschedule(context: context)
        return plan
    }

    /// Planned days stay between 1 and 365.
    static func clampedDays(_ days: Int) -> Int { min(max(days, 1), 365) }

    /// The note written on `day` (any time that day), if there is one.
    static func entry(on day: Date, in plan: ReadingPlan, calendar: Calendar = .current) -> StudyEntry? {
        plan.entries
            .filter { calendar.isDate($0.date, inSameDayAs: day) }
            .min { $0.createdAt < $1.createdAt }
    }

    /// First non-empty line of a note, for list rows. Empty when the note has no words.
    static func firstLine(of note: AttributedString) -> String {
        String(note.characters)
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
    }

    /// Adds a reminder unless the plan already has one at that time.
    @discardableResult
    static func addReminder(to plan: ReadingPlan, hour: Int, minute: Int, in context: ModelContext) -> ReadingReminder? {
        guard !plan.reminders.contains(where: { $0.hour == hour && $0.minute == minute }) else { return nil }
        let reminder = ReadingReminder(hour: hour, minute: minute)
        context.insert(reminder)
        reminder.plan = plan
        NotificationScheduler.shared.reschedule(context: context)
        return reminder
    }

    static func deleteReminder(_ reminder: ReadingReminder, in context: ModelContext) {
        context.delete(reminder)
        NotificationScheduler.shared.reschedule(context: context)
    }

    /// Starts an Up next book today.
    static func startReading(_ plan: ReadingPlan, now: Date = Date()) {
        guard plan.status == .upNext else { return }
        plan.status = .reading
        plan.startDate = now
        NotificationScheduler.shared.reschedule(context: plan.modelContext)
    }

    /// Toggles one chapter using the shared status rules.
    static func toggleChapter(_ chapter: Int, in plan: ReadingPlan, now: Date = Date()) {
        plan.setChapter(chapter, read: !plan.chaptersRead.contains(chapter), now: now)
        NotificationScheduler.shared.reschedule(context: plan.modelContext)
    }

    /// The first chapter not yet read, or the last chapter when all are read.
    static func nextChapter(in plan: ReadingPlan) -> Int {
        let last = max(plan.totalChapters, 1)
        return (1...last).first { !plan.chaptersRead.contains($0) } ?? last
    }

    /// Saves a new entry: inserts it and attaches it to the plan. Marks the chapter read if asked.
    static func saveNewEntry(
        _ entry: StudyEntry,
        to plan: ReadingPlan,
        markRead: Bool,
        now: Date = Date(),
        in context: ModelContext
    ) {
        if entry.modelContext == nil { context.insert(entry) }
        if let verse = entry.bestVerse, verse.modelContext == nil { context.insert(verse) }
        entry.plan = plan
        if markRead, !plan.chaptersRead.contains(entry.chapter) {
            plan.setChapter(entry.chapter, read: true, now: now)
            NotificationScheduler.shared.reschedule(context: context)
        }
    }

    /// Applies the "Mark chapter as read" toggle for an entry that already exists.
    static func applyReadToggle(_ markRead: Bool, chapter: Int, in plan: ReadingPlan, now: Date = Date()) {
        guard markRead != plan.chaptersRead.contains(chapter) else { return }
        plan.setChapter(chapter, read: markRead, now: now)
        NotificationScheduler.shared.reschedule(context: plan.modelContext)
    }

    /// Replaces the best verse, deleting the old one.
    static func setBestVerse(_ verse: VerseRef?, on entry: StudyEntry, in context: ModelContext) {
        if let old = entry.bestVerse, old.modelContext != nil {
            context.delete(old)
        }
        entry.bestVerse = verse
    }

    static func deletePlan(_ plan: ReadingPlan, in context: ModelContext) {
        context.delete(plan)
        NotificationScheduler.shared.reschedule(context: context)
    }

    // MARK: - Text

    static func timeText(hour: Int, minute: Int, calendar: Calendar = .current) -> String {
        var parts = DateComponents()
        parts.hour = hour
        parts.minute = minute
        let date = calendar.date(from: parts) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    static func remindersText(for plan: ReadingPlan) -> String? {
        let sorted = plan.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
        guard !sorted.isEmpty else { return nil }
        return "Reminder " + sorted.map { timeText(hour: $0.hour, minute: $0.minute) }.joined(separator: ", ")
    }

    static func chaptersText(_ count: Int) -> String {
        count == 1 ? "1 chapter" : "\(count) chapters"
    }

    static func progressText(for plan: ReadingPlan) -> String {
        "\(plan.chaptersRead.count) of \(plan.totalChapters) chapters read"
    }

    /// For example "Day 3 of 14 · 1 chapter a day".
    static func planLine(for plan: ReadingPlan, now: Date = Date()) -> String {
        switch plan.status {
        case .reading:
            let pace = plan.pace(now: now)
            return "Day \(pace.dayNumber) of \(pace.plannedDays) · \(chaptersText(pace.chaptersPerDay)) a day"
        case .upNext:
            return "\(plan.plannedDays) days · starts when you begin"
        case .done:
            if let finished = plan.finishedDate {
                return "Finished \(finished.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Finished"
        }
    }
}

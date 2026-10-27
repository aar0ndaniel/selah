import Foundation
import SwiftData
import WidgetKit

extension StreakInput {
    /// Plain values for the streak rules, from the store's plans, entries, services and meeting days.
    static func from(
        plans: [ReadingPlan],
        entries: [StudyEntry],
        services: [Service],
        meetingDays: [MeetingDay]
    ) -> StreakInput {
        var spans: [ReadingSpan] = []
        for plan in plans where plan.status != .upNext {
            let dates = plan.entries.map { $0.date }
            guard let start = plan.startDate ?? dates.min() else { continue }
            let end: Date? = plan.status == .done ? (plan.finishedDate ?? dates.max() ?? start) : nil
            spans.append(ReadingSpan(start: start, end: end))
        }
        return StreakInput(
            studyDates: entries.map { $0.date },
            serviceDates: services.map { $0.date },
            meetingWeekdays: Set(meetingDays.filter { $0.isActive }.map { $0.weekday }),
            readingSpans: spans
        )
    }
}

/// Writes the home screen widget snapshot from the store and asks WidgetKit to redraw when it changed.
/// Called when the app becomes active and when it goes to the background.
@MainActor
enum WidgetSync {
    static func refresh(context: ModelContext, now: Date = Date()) {
        let plans = (try? context.fetch(FetchDescriptor<ReadingPlan>())) ?? []
        let entries = (try? context.fetch(FetchDescriptor<StudyEntry>())) ?? []
        let services = (try? context.fetch(FetchDescriptor<Service>())) ?? []
        let meetingDays = (try? context.fetch(FetchDescriptor<MeetingDay>())) ?? []
        let moods = (try? context.fetch(FetchDescriptor<MoodEntry>())) ?? []
        let translation = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first?.translation ?? .kjv

        let defaults = UserDefaults.standard
        let kind = StreakKind(rawValue: defaults.string(forKey: StreakKind.storageKey) ?? "") ?? .study
        let mode = MascotMode(storedValue: defaults.string(forKey: MascotMode.storageKey) ?? "")

        let calendar = Calendar.current
        let chosen = entries
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .compactMap { $0.bestVerse }
            .first
            .map { WidgetSnapshotBuilder.Passage(text: $0.textSnapshot, reference: "\($0.reference) (\($0.translation.shortName))") }
        let passages = PopularPassages.all.map { ref in
            WidgetSnapshotBuilder.Passage(
                text: BibleStore.shared.text(for: ref, translation: translation),
                reference: "\(ref.displayString) (\(translation.shortName))"
            )
        }
        let todayMood = moods
            .filter { calendar.isDate($0.date, inSameDayAs: now) }
            .max { $0.createdAt < $1.createdAt }

        let snapshot = WidgetSnapshotBuilder.build(
            input: StreakInput.from(plans: plans, entries: entries, services: services, meetingDays: meetingDays),
            kind: kind,
            mascotMode: mode,
            chosenVerse: chosen,
            passages: passages,
            mood: todayMood?.mood,
            moodDate: todayMood?.date,
            now: now,
            calendar: calendar
        )
        guard snapshot != WidgetStore.load() else { return }
        if WidgetStore.save(snapshot) {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

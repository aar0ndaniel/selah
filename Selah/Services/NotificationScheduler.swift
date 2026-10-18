import Foundation
import SwiftData
import UserNotifications

/// Shows reminders as banners while the app is open.
final class NotificationPresenter: NSObject, UNUserNotificationCenterDelegate, Sendable {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let presenter = NotificationPresenter()
    private var generation = 0

    private init() {}

    /// Call once at launch so reminders show while the app is open.
    func installDelegate() {
        UNUserNotificationCenter.current().delegate = presenter
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Convenience for code that only has an optional context.
    func reschedule(context: ModelContext?) {
        guard let context else { return }
        reschedule(context: context)
    }

    /// Rebuilds all reading and meeting reminders from the stored data.
    func reschedule(context: ModelContext) {
        let plans = (try? context.fetch(FetchDescriptor<ReadingPlan>())) ?? []
        let days = (try? context.fetch(FetchDescriptor<MeetingDay>())) ?? []

        let planSnapshots = plans.map { plan in
            PlanSnapshot(
                id: Self.stableID(plan.persistentModelID),
                bookName: plan.bookName,
                status: plan.status,
                chaptersRead: plan.chaptersRead,
                totalChapters: plan.totalChapters,
                reminders: plan.reminders.map { ReminderTime(hour: $0.hour, minute: $0.minute) }
            )
        }
        let daySnapshots = days.map { day in
            MeetingSnapshot(
                id: Self.stableID(day.persistentModelID),
                weekday: day.weekday,
                hour: day.hour,
                minute: day.minute,
                name: day.name,
                reminderMinutesBefore: day.reminderMinutesBefore,
                isActive: day.isActive
            )
        }

        // Keep each reminder's stored notification ID in step with what is scheduled.
        for plan in plans {
            let planID = Self.stableID(plan.persistentModelID)
            for reminder in plan.reminders {
                let id = NotificationPlanner.readingIdentifier(planID: planID, hour: reminder.hour, minute: reminder.minute)
                if reminder.notificationID != id { reminder.notificationID = id }
            }
        }

        let planned = NotificationPlanner.plan(plans: planSnapshots, meetings: daySnapshots)
        generation += 1
        let token = generation
        Task { @MainActor in
            await self.apply(planned, token: token)
        }
    }

    private func apply(_ planned: [PlannedNotification], token: Int) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let existing = pending.map(\.identifier)
        // A newer reschedule has started; let it finish the job.
        guard token == generation else { return }

        let wanted = Set(planned.map(\.identifier))
        let stale = existing.filter { id in
            (id.hasPrefix(NotificationPlanner.readingPrefix) || id.hasPrefix(NotificationPlanner.meetingPrefix))
                && !wanted.contains(id)
        }
        if !stale.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: stale)
        }

        for item in planned {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: item.trigger, repeats: item.repeats)
            let request = UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    /// Model IDs only live in memory as text; strip anything that is not safe in an identifier.
    private static func stableID(_ id: PersistentIdentifier) -> String {
        var out = ""
        for scalar in String(describing: id).unicodeScalars {
            out.append(CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "_")
        }
        return out
    }
}

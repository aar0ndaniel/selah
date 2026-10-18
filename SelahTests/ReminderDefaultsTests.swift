import Foundation
import Testing
@testable import Selah

struct ReminderDefaultsTests {
    @Test func readingTimeUsesStoredMinutes() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: ReminderDefaults.readingKey)
        defaults.set(8 * 60 + 30, forKey: ReminderDefaults.readingKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: ReminderDefaults.readingKey)
            } else {
                defaults.removeObject(forKey: ReminderDefaults.readingKey)
            }
        }
        let parts = Calendar.current.dateComponents([.hour, .minute], from: ReminderDefaults.readingTime())
        #expect(parts.hour == 8)
        #expect(parts.minute == 30)
    }

    @Test func serviceMinutesUsesStoredValue() {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: ReminderDefaults.serviceKey)
        defaults.set(30, forKey: ReminderDefaults.serviceKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: ReminderDefaults.serviceKey)
            } else {
                defaults.removeObject(forKey: ReminderDefaults.serviceKey)
            }
        }
        #expect(ReminderDefaults.serviceMinutes == 30)
    }
}

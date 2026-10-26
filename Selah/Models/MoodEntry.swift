import Foundation
import SwiftData

/// One answer to "How are you feeling today?". At most one a day is kept by the check-in (a second answer on the
/// same day updates it).
@Model
final class MoodEntry {
    var date: Date = Date()
    /// `MascotMood` raw value. Stored as a string so an unknown value from a newer version survives a backup.
    var moodRaw: String = MascotMood.peaceful.rawValue
    var note: String = ""
    var createdAt: Date = Date()

    var mood: MascotMood {
        get { MascotMood(rawValue: moodRaw) ?? .peaceful }
        set { moodRaw = newValue.rawValue }
    }

    init(
        date: Date = Date(),
        mood: MascotMood = .peaceful,
        note: String = "",
        createdAt: Date = Date()
    ) {
        self.date = date
        self.moodRaw = mood.rawValue
        self.note = note
        self.createdAt = createdAt
    }
}

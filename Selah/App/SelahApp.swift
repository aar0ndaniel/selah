import SwiftUI
import SwiftData

@main
struct SelahApp: App {
    init() {
        // Show reminders as banners even while the app is open.
        NotificationScheduler.shared.installDelegate()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            UserProfile.self,
            MeetingDay.self,
            ReadingPlan.self,
            ReadingReminder.self,
            StudyEntry.self,
            Service.self,
            Song.self,
            PersonalNote.self,
            VerseRef.self,
            NoteComment.self
        ])
    }
}

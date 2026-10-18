import SwiftUI
import SwiftData

@main
struct SelahApp: App {
    private let launch: LaunchOptions
    /// Set only for UI-test launches (see `LaunchOptions`); nil in normal use.
    private let testContainer: ModelContainer?

    init() {
        // Show reminders as banners even while the app is open.
        NotificationScheduler.shared.installDelegate()
        // Serif large and inline navigation titles.
        NavigationAppearance.install()

        let options = LaunchOptions.current
        launch = options
        testContainer = options.makeTestContainer()
    }

    var body: some Scene {
        WindowGroup {
            AppRoot(launch: launch, testContainer: testContainer)
        }
    }
}

/// Chooses the data store: the real SwiftData store, or an in-memory one for screenshot test launches.
private struct AppRoot: View {
    let launch: LaunchOptions
    let testContainer: ModelContainer?

    var body: some View {
        if let testContainer {
            RootTabView(forcedScheme: launch.forcedScheme)
                .modelContainer(testContainer)
        } else {
            RootTabView(forcedScheme: launch.forcedScheme)
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
}

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
        // Bundled DM Sans and Space Grotesk must be registered before any view asks for them.
        FontRegistry.registerAll()
        // Space Grotesk large and inline navigation titles.
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

    /// The mascot colour the accent was last drawn with. The accent follows Selah's colour; when it changes, the
    /// screens are rebuilt once (on Settings closing, onboarding finishing, or the app coming back) so every view picks
    /// it up, without rebuilding under an open sheet.
    @State private var appliedMode = AccentPalette.current
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        root
            .id(appliedMode)
            // The asset-catalog global accent wasn't being applied (screens rendered system blue),
            // so set it explicitly: `.tint` drives controls, `.accentColor` drives `Color.accentColor`.
            .tint(Theme.accent)
            .accentColor(Theme.accent)
            .onReceive(NotificationCenter.default.publisher(for: AccentPalette.refresh)) { _ in
                appliedMode = AccentPalette.current
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { appliedMode = AccentPalette.current }
            }
    }

    @ViewBuilder
    private var root: some View {
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
                    ServicePart.self,
                    LibrarySong.self,
                    PersonalNote.self,
                    VerseRef.self,
                    NoteComment.self,
                    MoodEntry.self
                ])
        }
    }
}

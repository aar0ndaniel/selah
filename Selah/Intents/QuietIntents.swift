import AppIntents

// App Intents for Quiet time. They open Selah (`openAppWhenRun`) and hand the destination to `QuietIntentRouter`.
// No entitlement is needed, so they work with a free Apple ID.

struct StartQuietTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Start quiet time"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuietIntentRouter.shared.request(.today, showBanner: true)
        return .result()
    }
}

struct StartStudySessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start study session"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuietIntentRouter.shared.request(.studySession, showBanner: false)
        return .result()
    }
}

struct StartServiceNotesIntent: AppIntent {
    static let title: LocalizedStringResource = "Start service notes"
    static let openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuietIntentRouter.shared.request(.serviceNotes, showBanner: false)
        return .result()
    }
}

/// Phrases for Siri, Spotlight and the Shortcuts app. The symbol names are SF Symbols because this is system UI.
struct SelahShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartQuietTimeIntent(),
            phrases: ["Start quiet time in \(.applicationName)"],
            shortTitle: "Start quiet time",
            systemImageName: "moon.fill"
        )
        AppShortcut(
            intent: StartStudySessionIntent(),
            phrases: ["Start a study session in \(.applicationName)"],
            shortTitle: "Start study session",
            systemImageName: "book.fill"
        )
        AppShortcut(
            intent: StartServiceNotesIntent(),
            phrases: ["Start service notes in \(.applicationName)"],
            shortTitle: "Start service notes",
            systemImageName: "building.columns.fill"
        )
    }
}

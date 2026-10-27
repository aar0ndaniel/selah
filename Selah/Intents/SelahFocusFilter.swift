import AppIntents

/// The pages a Focus filter can open Selah to. Shown as "Open to" when the user adds the Selah filter to a Focus.
enum QuietOpenTo: String, AppEnum, CaseIterable {
    case today
    case studySession
    case serviceNotes

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Open to")

    static let caseDisplayRepresentations: [QuietOpenTo: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: "Today"),
        .studySession: DisplayRepresentation(title: "Study session"),
        .serviceNotes: DisplayRepresentation(title: "Service notes")
    ]

    /// Plain text for the filter's summary line.
    var title: String {
        switch self {
        case .today: return "Today"
        case .studySession: return "Study session"
        case .serviceNotes: return "Service notes"
        }
    }

    var destination: QuietDestination {
        switch self {
        case .today: return .today
        case .studySession: return .studySession
        case .serviceNotes: return .serviceNotes
        }
    }
}

/// Focus filter. Appears under Settings > Focus > (your Focus) > Focus filters > Add filter > Selah.
///
/// iOS runs `perform()` when the Focus turns on and, as far as Apple documents, also when the filter's settings
/// change or the Focus turns off. There is no documented flag that says which one it was, so every call is stored as an
/// activation with a timestamp and `QuietFocusRule` keeps that safe (one navigation per activation, ignored after
/// two hours).
struct SelahFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Tehila"

    @Parameter(title: "Open to", default: .today)
    var openTo: QuietOpenTo

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "Tehila", subtitle: "Opens to \(openTo.title)")
    }

    func perform() async throws -> some IntentResult {
        QuietFocusStore.recordActivation(destination: openTo.destination)
        await QuietIntentRouter.shared.focusFilterApplied()
        return .result()
    }
}

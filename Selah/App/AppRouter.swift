import SwiftUI
import Observation

enum AppTab: Hashable, CaseIterable {
    case today, study, services, notes

    /// Visible tab title (also the VoiceOver label and the XCUITest handle).
    var title: String {
        switch self {
        case .today: return "Today"
        case .study: return "Study"
        case .services: return "Services"
        case .notes: return "Notes"
        }
    }

    /// Phosphor icon. Regular when idle, fill when selected.
    var icon: PIcon {
        switch self {
        case .today: return .sun
        case .study: return .bookOpen
        case .services: return .church
        case .notes: return .note
        }
    }

    var identifier: String {
        switch self {
        case .today: return "tab-today"
        case .study: return "tab-study"
        case .services: return "tab-services"
        case .notes: return "tab-notes"
        }
    }
}

enum PlusAction: Hashable {
    case writeTodayEntry, addBook, newService, newNote
    /// Quiet time: open today's service page (create it when there is none). Handled by ServicesView.
    case openTodayService
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    /// Set by the + button; the feature view for that tab handles it and clears it.
    var pendingAction: PlusAction?

    /// True while the keyboard is up. The + button steps aside because it would sit on top of the keyboard.
    var keyboardVisible = false
    /// Screens that must not show the + button (full-page editors) register here with `.hidesPlusButton()`.
    var plusHiders: Set<UUID> = []

    var plusButtonHidden: Bool { keyboardVisible || !plusHiders.isEmpty }

    func hidePlus(_ token: UUID) { plusHiders.insert(token) }
    func showPlus(_ token: UUID) { plusHiders.remove(token) }
}

extension View {
    /// Hides the floating + button while this view is on screen. Use on pushed full pages and editors
    /// that have their own primary action.
    func hidesPlusButton() -> some View {
        modifier(HidesPlusButton())
    }
}

private struct HidesPlusButton: ViewModifier {
    @Environment(AppRouter.self) private var router
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onAppear { router.hidePlus(token) }
            .onDisappear { router.showPlus(token) }
    }
}

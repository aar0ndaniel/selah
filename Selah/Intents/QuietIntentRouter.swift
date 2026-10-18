import Foundation
import Observation

/// Hand-off from App Intents and the Focus filter to the UI.
///
/// Intents with `openAppWhenRun` run inside the app's own process, so a main-actor singleton is shared with the
/// SwiftUI views. The intent only writes `pending` / `isQuietTimeOn`; `RootTabView` observes `pending` (with
/// `initial: true`, so it also catches a value set before the view first appeared, which is what happens on a cold
/// launch) and turns it into `AppRouter.selectedTab` + `pendingAction`.
@MainActor
@Observable
final class QuietIntentRouter {
    static let shared = QuietIntentRouter()

    /// Where the UI should go next. `RootTabView` clears it once it has navigated.
    var pending: QuietDestination?

    /// True while the "Quiet time is on" card shows on Today. In memory only: a fresh launch starts without it.
    var isQuietTimeOn = false

    /// Kept up to date by `RootTabView` from the scene phase. The Focus filter may run while Selah is already open.
    var isSceneActive = false

    init() {}

    /// Used by the three intents. `showBanner` turns the Today card on.
    func request(_ destination: QuietDestination, showBanner: Bool) {
        if showBanner { isQuietTimeOn = true }
        pending = destination
    }

    /// The in-app "Try it" button: shows the card without navigating anywhere.
    func startQuietTime() {
        isQuietTimeOn = true
    }

    /// The card's End button. Only hides the card; it does not touch the user's Focus.
    func endQuietTime() {
        isQuietTimeOn = false
    }

    /// Opens the Focus filter's chosen page once per Focus session (see `QuietFocusRule`).
    func consumeFocusSession(now: Date = Date()) {
        guard let record = QuietFocusStore.load(),
              let destination = QuietFocusRule.destinationToOpen(record, now: now)
        else { return }
        QuietFocusStore.markHandled(record)
        pending = destination
    }

    /// Called by the Focus filter after it saved a new record. If Selah is already open, go now; otherwise the next
    /// `.active` scene phase picks it up.
    func focusFilterApplied() {
        if isSceneActive { consumeFocusSession() }
    }
}

extension AppRouter {
    /// Translates a quiet-time destination into the tab and + action the feature views already understand.
    func open(_ destination: QuietDestination) {
        switch destination {
        case .today:
            selectedTab = .today
        case .studySession:
            // Same path as the + button on Today: opens today's note, or Study's Add book when there is no book.
            selectedTab = .today
            pendingAction = .writeTodayEntry
        case .serviceNotes:
            selectedTab = .services
            pendingAction = .openTodayService
        }
    }
}

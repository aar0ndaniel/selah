import SwiftUI
import Observation

enum AppTab: Hashable {
    case today, study, services, notes
}

enum PlusAction: Hashable {
    case writeTodayEntry, addBook, newService, newNote
}

@MainActor
@Observable
final class AppRouter {
    var selectedTab: AppTab = .today
    /// Set by the + button; the feature view for that tab handles it and clears it.
    var pendingAction: PlusAction?
}

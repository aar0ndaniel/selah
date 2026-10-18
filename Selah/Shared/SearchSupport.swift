import SwiftUI

/// iOS 26 bottom search helpers.
///
/// On iPhone, `.searchable` in a NavigationStack renders as the floating Liquid Glass capsule at the bottom of the
/// screen (iOS 26 default). `.bottomSearchField()` adds the explicit `DefaultToolbarItem(kind: .search, placement: .bottomBar)`
/// so the capsule is always in the bottom bar, then call `.searchable` on the same view as usual.
extension View {
    /// Toolbar content that places the system search field in the bottom bar. Needs `.searchable` on the same stack.
    func bottomSearchToolbar() -> some View {
        toolbar {
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
        }
    }

    /// Hides the floating + button while the search field is active. Apply to the content INSIDE `.searchable`
    /// (that is, before `.searchable` in the modifier chain) because `isSearching` is set for the searched content.
    func hidesPlusWhileSearching() -> some View {
        modifier(SearchPlusHider())
    }
}

private struct SearchPlusHider: ViewModifier {
    @Environment(\.isSearching) private var isSearching
    @Environment(AppRouter.self) private var router
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .onChange(of: isSearching) { _, searching in
                if searching { router.hidePlus(token) } else { router.showPlus(token) }
            }
            .onDisappear { router.showPlus(token) }
    }
}

import SwiftUI

/// The page background: plain `systemBackground` (white in light mode, black in dark mode).
///
/// Round 2 removed the gradient. The type stays so existing call sites (`.background { AppBackground() }`) compile;
/// new code can simply rely on the default background of a scroll view or use this for a container that
/// would otherwise be transparent. Colour belongs in cards, pills and buttons, never in the page.
struct AppBackground: View {
    var body: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    AppBackground()
}

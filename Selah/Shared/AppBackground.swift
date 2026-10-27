import SwiftUI

/// The page background, like iOS Settings (owner, 27 Oct): `systemGroupedBackground`, light grey in light mode and
/// black in dark mode, so the white cards stand out without shadows. Colour belongs in cards, pills and buttons,
/// never in the page.
struct AppBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

#Preview {
    AppBackground()
}

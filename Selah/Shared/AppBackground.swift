import SwiftUI

/// Soft teal, mint and sky background. Use behind content only.
struct AppBackground: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        Group {
            if reduceTransparency || contrast == .increased {
                Color(.systemGroupedBackground)
            } else {
                LinearGradient(
                    colors: [
                        Theme.Palette.backgroundTop,
                        Theme.Palette.backgroundMid,
                        Theme.Palette.backgroundBottom
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

#Preview {
    AppBackground()
}

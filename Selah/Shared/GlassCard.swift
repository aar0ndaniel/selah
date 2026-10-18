import SwiftUI

/// Hero container: use for at most one element per screen (for example verse of the day).
struct GlassCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.l)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.Radius.card))
    }
}

/// Ordinary content card. Flat fill, not glass.
struct SurfaceCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: Theme.Spacing.m) {
            GlassCard {
                Text("The Lord is my shepherd; I shall not want.")
                    .font(.title3)
            }
            SurfaceCard {
                Text("An ordinary card").font(.headline)
            }
        }
        .padding(Theme.Spacing.m)
    }
}

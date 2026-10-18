import SwiftUI

/// Hero container: use for at most one element per screen (for example verse of the day).
/// Glass needs something to refract, so prefer `ToneCard` on the plain page background unless the card sits
/// over an image or a banner.
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

/// Ordinary content card on the plain page: neutral `secondarySystemBackground`, radius 20, no shadow, not glass.
/// Looks right on white (light) and on black (dark).
struct SurfaceCard<Content: View>: View {
    private let content: Content
    private let onGroupedPage: Bool

    /// - Parameter onGroupedPage: true on a `systemGroupedBackground` page (Settings style): the card is
    ///   `secondarySystemGroupedBackground` with the iOS 26 grouped corner radius (26pt).
    init(onGroupedPage: Bool = false, @ViewBuilder content: () -> Content) {
        self.onGroupedPage = onGroupedPage
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.m)
            .background(
                onGroupedPage ? Color(.secondarySystemGroupedBackground) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: onGroupedPage ? 26 : Theme.Radius.card, style: .continuous)
            )
    }
}

/// Coloured content card: `tone.fill` background, radius 20, no shadow (the tint is the separation).
/// In light mode the fill is a pale tint of the tone. In dark mode it is the same neutral #1C1C1E for every tone
/// (like an iOS Settings card), with no border: the colour then lives only in `tone.ink` icons and tiny labels.
/// Callers choose text colours: `.primary` for body text, `tone.onSurface` for titles, `tone.ink` for icons and short
/// labels, `tone.inkSecondary` for quieter text. Never use system `.secondary` on a light tone fill.
struct ToneCard<Content: View>: View {
    private let tone: Tone
    private let padding: CGFloat
    private let content: Content

    init(tone: Tone, padding: CGFloat = Theme.Spacing.m, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                tone.fill,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
    }
}

extension View {
    /// Draws the view on a tone-coloured card (same look as `ToneCard`), without wrapping it.
    func toneCard(_ tone: Tone, padding: CGFloat = Theme.Spacing.m) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                tone.fill,
                in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
            )
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Theme.Spacing.m) {
            GlassCard {
                Text("The Lord is my shepherd; I shall not want.")
                    .font(.selahVerse)
            }
            SurfaceCard {
                Text("An ordinary card").font(.selahCardTitle)
            }
            ForEach(Tone.allCases, id: \.self) { tone in
                ToneCard(tone: tone) {
                    HStack {
                        PIconView(.bookOpen, size: 22)
                            .foregroundStyle(tone.ink)
                        Text(tone.name).font(.selahHeadline).foregroundStyle(tone.onSurface)
                        Spacer()
                        Text("Reading").font(.selahLabelSmall).foregroundStyle(tone.inkSecondary)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
    }
}

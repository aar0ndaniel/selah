import SwiftUI
import UIKit

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

extension Theme {
    /// Card surface (owner, 27 Oct): Apple white in light mode, the iOS dark card #1C1C1E in dark mode. Never the
    /// light grey `secondarySystemBackground` in light mode.
    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.11, green: 0.11, blue: 0.118, alpha: 1) : .white
    })
    /// Soft lift that separates a white card from the white page. Clear in dark mode (the card colour does it).
    static let cardShadow = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .clear : UIColor(white: 0, alpha: 0.07)
    })
    /// Hairline edge for white cards in light mode.
    static let cardEdge = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? .clear : UIColor(white: 0, alpha: 0.05)
    })
}

extension View {
    /// Draws the view on the standard card: `Theme.card`, a hairline edge and a soft shadow in light mode.
    func selahCard(radius: CGFloat = Theme.Radius.card) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return self
            .background(Theme.card, in: shape)
            .overlay { shape.strokeBorder(Theme.cardEdge, lineWidth: 0.5) }
            .shadow(color: Theme.cardShadow, radius: 12, x: 0, y: 4)
    }
}

/// Ordinary content card on the plain page: `Theme.card` (white / #1C1C1E) with a soft lift, radius 20, not glass.
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

    @ViewBuilder
    var body: some View {
        if onGroupedPage {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
        } else {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .selahCard()
        }
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

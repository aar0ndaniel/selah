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
    /// Card surface, like iOS Settings (owner, 27 Oct): white in light mode, #1C1C1E in dark mode, on the grey
    /// grouped page. The page colour is the separation: no shadows, no borders.
    static let card = Color(.secondarySystemGroupedBackground)
    /// A surface one step up inside a card or a tinted frame: white in light mode, #2C2C2E in dark mode.
    static let cardRaised = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.173, green: 0.173, blue: 0.180, alpha: 1) : .white
    })
    /// Kept for callers; cards no longer cast shadows or draw edges.
    static let cardShadow = Color.clear
    static let cardEdge = Color.clear
}

extension View {
    /// Draws the view on the standard card: `Theme.card` on the grey page, flat (no shadow, no border).
    func selahCard(radius: CGFloat = Theme.Radius.card) -> some View {
        self.background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
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

/// Hero card in the focus-card style (owner, 27 Oct): the same warm tinted frame as the study focus card, and the
/// content on a Liquid Glass panel inset inside it (the frame is what the glass refracts). Dark mode follows iOS: a
/// neutral #1C1C1E frame with a lifted glass panel. Callers choose text colours: `.primary` for body text,
/// `tone.onSurface` for titles, `tone.ink` for icons and short labels, `tone.inkSecondary` for quieter text.
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
        content.toneCard(tone, padding: padding)
    }
}

extension Theme {
    /// Tint for glass panels on a tinted frame: mostly white in light mode, a lifted grey in dark mode.
    /// The warm frame behind glass cards (same as the study focus card): pale blush to near white; dark #1C1C1E.
    static let frameTop = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
            : UIColor(red: 0.949, green: 0.886, blue: 0.894, alpha: 1)
    })
    static let frameBottom = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.086, green: 0.086, blue: 0.094, alpha: 1)
            : UIColor(red: 0.976, green: 0.953, blue: 0.957, alpha: 1)
    })
    static let glassTint = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(white: 0.22, alpha: 0.55) : UIColor(white: 1, alpha: 0.6)
    })
}

extension View {
    /// Draws the view as a `ToneCard`: a glass panel inside the warm frame. `tone` is kept for callers, which use it
    /// for their ink colours.
    func toneCard(_ tone: Tone, padding: CGFloat = Theme.Spacing.m) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Theme.cardRaised, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(6)
            .background(
                LinearGradient(colors: [Theme.frameTop, Theme.frameBottom], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
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

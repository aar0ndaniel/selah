import SwiftUI
import UIKit

/// Semantic tokens. Colours live in the asset catalog (light and dark variants).
/// Never use gold, yellow, amber, purple, violet, lavender or indigo.
///
/// The full system (tones with hex values, type scale, buttons, icons) is written up in docs/DESIGN-SYSTEM.md.
enum Theme {
    /// 8pt grid.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        /// Extra breathing room at the end of a scroll view above the floating + button.
        /// The + button is placed with `safeAreaInset` in RootTabView, which already insets scroll content by the
        /// button's height, so this is only a small margin. If a screenshot ever shows the last row under the
        /// + button, raise this to 72 (56pt button + 16pt gap) in this one place.
        static let plusButtonClearance: CGFloat = 16
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        /// Cards, hero blocks and sticky notes.
        static let card: CGFloat = 20
    }

    /// Minimum tap target (HIG).
    static let minTapTarget: CGFloat = 44

    /// Single-colour tokens that are not part of a tone pair.
    enum Palette {
        // `highlightMint` (text highlight) is declared in RichNoteEditor.swift.
    }
}

// MARK: - Tones

/// A card / pill colour pair.
///
/// - `fill`: the soft tint behind a card, pill or secondary button. Very pale in light mode, deep and muted in dark mode.
/// - `ink`: the strong foreground for icons and labels that sit on that fill.
///
/// Contrast (WCAG, computed from the asset values, see docs/DESIGN-SYSTEM.md):
/// every `ink` on its own `fill` is 7.3:1 or better in light mode and 8.2:1 or better in dark mode,
/// so body-size text passes AA with room to spare. `inkSecondary` (ink at 85%) stays above 4.5:1 in every tone.
/// Do not put system `.secondary` text on a fill: it is a grey and drops to about 4:1 on the paler tones.
///
/// Teal is the accent family. As a tone it is for tinted pills and cards that relate to the app's identity;
/// the interactive accent colour itself is `Color.accentColor` (AccentColor asset), never a tone.
enum Tone: CaseIterable, Hashable, Sendable {
    case teal, coral, sky, sage, rose, sand, slate, mint

    /// Name of the asset colour pair, for example "ToneCoral".
    private var assetPrefix: String {
        switch self {
        case .teal: return "ToneTeal"
        case .coral: return "ToneCoral"
        case .sky: return "ToneSky"
        case .sage: return "ToneSage"
        case .rose: return "ToneRose"
        case .sand: return "ToneSand"
        case .slate: return "ToneSlate"
        case .mint: return "ToneMint"
        }
    }

    /// Soft tint for cards, pills and sticky notes.
    var fill: Color { Color(assetPrefix + "Fill") }

    /// Strong foreground (icon, label) for use on `fill`.
    var ink: Color { Color(assetPrefix + "Ink") }

    /// Quieter text on `fill`: ink at 85%, still at least 4.5:1.
    var inkSecondary: Color { ink.opacity(0.85) }

    /// Plain-word name, for accessibility labels and pickers.
    var name: String {
        switch self {
        case .teal: return "Teal"
        case .coral: return "Coral"
        case .sky: return "Sky"
        case .sage: return "Sage"
        case .rose: return "Rose"
        case .sand: return "Sand"
        case .slate: return "Slate"
        case .mint: return "Mint"
        }
    }
}

extension NoteColour {
    /// The tone this note colour is drawn with. Raw values are stored in SwiftData, so `peach` keeps its name
    /// and maps to coral.
    var tone: Tone {
        switch self {
        case .peach: return .coral
        case .sage: return .sage
        case .mint: return .mint
        case .sky: return .sky
        case .rose: return .rose
        case .sand: return .sand
        }
    }

    /// Pale fill in light mode, deep muted fill in dark mode. Use `ink` / `.primary` text on top.
    var color: Color { tone.fill }

    /// Strong foreground for icons and labels on this note colour.
    var ink: Color { tone.ink }
}

// MARK: - Typography

/// Type scale. Text styles only, so everything follows Dynamic Type.
/// - SF (default design) carries UI: body, labels, controls.
/// - New York serif carries page titles, section headings, verses and book names.
/// - Numbers in stats use monospaced digits so they do not jiggle when they change.
extension Font {
    /// Page title in the content area (large title, serif, semibold).
    static var selahDisplay: Font { .system(.largeTitle, design: .serif, weight: .semibold) }
    /// Section heading (title 2, serif, semibold).
    static var selahTitle: Font { .system(.title2, design: .serif, weight: .semibold) }
    /// Card heading (title 3, serif, semibold).
    static var selahCardTitle: Font { .system(.title3, design: .serif, weight: .semibold) }
    /// Small heading, for example a book name in a row (headline, serif, semibold).
    static var selahHeadline: Font { .system(.headline, design: .serif, weight: .semibold) }
    /// Scripture text, reading size (title 3, serif, regular).
    static var selahVerse: Font { .system(.title3, design: .serif, weight: .regular) }
    /// Hero scripture text, for example verse of the day (title 2, serif, regular).
    static var selahVerseLarge: Font { .system(.title2, design: .serif, weight: .regular) }
    /// Compact scripture text in lists and cards (body, serif, regular).
    static var selahVerseCompact: Font { .system(.body, design: .serif, weight: .regular) }
    /// Stat number, large (largeTitle, serif, semibold, monospaced digits).
    static var selahStatLarge: Font { Font.system(.largeTitle, design: .serif, weight: .semibold).monospacedDigit() }
    /// Stat number (title, serif, semibold, monospaced digits).
    static var selahStat: Font { Font.system(.title, design: .serif, weight: .semibold).monospacedDigit() }
    /// Small stat number, for example inside a pill or a ring (subheadline, semibold, monospaced digits).
    static var selahStatSmall: Font { Font.system(.subheadline, design: .default, weight: .semibold).monospacedDigit() }
    /// Small caps-style label above a group. Pair with `.selahEyebrow()`.
    static var selahEyebrow: Font { .system(.caption, design: .default, weight: .semibold) }
}

extension View {
    /// Eyebrow label: caption, semibold, uppercase, slightly tracked, secondary colour.
    /// Use it to name a group of content (for example "NEXT GATHERING"), not above every heading.
    func selahEyebrow() -> some View {
        self
            .font(.selahEyebrow)
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(.secondary)
    }
}

/// Serif large and inline titles in navigation bars.
///
/// SwiftUI has no API for the navigation title font, so this configures the UIKit appearance proxy once at app start.
/// Only the title text attributes are touched, so the iOS 26 Liquid Glass bar and scroll-edge effect are untouched.
/// The fonts are built with `UIFontMetrics`, so they honour the Dynamic Type size in force when the bar is created.
enum NavigationAppearance {
    @MainActor
    static func install() {
        let large = serifFont(for: .largeTitle, weight: .semibold)
        let inline = serifFont(for: .headline, weight: .semibold)

        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [.font: large]
        appearance.titleTextAttributes = [.font: inline]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.compactAppearance = appearance
        // scrollEdgeAppearance is left nil on purpose: UIKit then derives it from `standardAppearance`
        // with the transparent large-title background, keeping the serif title attributes.
    }

    /// New York serif for a text style, scaled with Dynamic Type.
    static func serifFont(for style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        // The unscaled design size for this style (at the default "large" content size).
        let reference = UIFont.preferredFont(
            forTextStyle: style,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        let base = UIFont.systemFont(ofSize: reference.pointSize, weight: weight)
        let font: UIFont
        if let descriptor = base.fontDescriptor.withDesign(.serif) {
            font = UIFont(descriptor: descriptor, size: reference.pointSize)
        } else {
            font = base
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: font)
    }
}

#Preview("Tones") {
    ScrollView {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(Tone.allCases, id: \.self) { tone in
                HStack {
                    Text(tone.name)
                        .font(.selahHeadline)
                    Spacer()
                    Text("Ink on fill")
                        .font(.subheadline)
                        .foregroundStyle(tone.inkSecondary)
                }
                .foregroundStyle(tone.ink)
                .padding(Theme.Spacing.m)
                .background(tone.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
            }
        }
        .padding(Theme.Spacing.m)
    }
}

#Preview("Type") {
    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
        Text("Page title").font(.selahDisplay)
        Text("Section heading").font(.selahTitle)
        Text("Card heading").font(.selahCardTitle)
        Text("The Lord is my shepherd; I shall not want.").font(.selahVerse)
        Text("Next gathering").selahEyebrow()
        Text("1,234").font(.selahStat)
    }
    .padding(Theme.Spacing.m)
}

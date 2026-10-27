import SwiftUI
import UIKit
import CoreText

/// Semantic tokens. Colours live in the asset catalog (light and dark variants).
/// Never use gold, yellow, amber, purple, violet, lavender, indigo or blue.
///
/// The full system (tones with hex values, contrast table, type scale, buttons, icons) is written up in
/// docs/DESIGN-SYSTEM.md.
enum Theme {
    /// The brand accent #D33E43 (dark mode #E2585D), read straight from the asset catalog.
    /// Interactive elements only; never a page background.
    static let accent = Color("AccentColor")
    /// Label and icon colour for anything filled with `accent` (Material "on-primary"): white on #D33E43 in light mode
    /// (4.6:1), deep red #2A0004 on #E2585D in dark mode (5.3:1). White on the dark accent would only be 3.6:1.
    static let onAccent = Color("AccentOn")
    /// Quiet accent container for secondary buttons and selected toggles (light #FBE9EA / dark #2C2C2E, a neutral
    /// raised grey like iOS Settings; the red lives in `brandInk`).
    static let brandFill = Color("BrandFill")
    /// Accent ink on `brandFill` (light #A42A2F / dark #FFB3B1): 6.1:1 light, 8.2:1 dark.
    static let brandInk = Color("BrandInk")

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
        /// Cards and hero blocks: the iOS 26 grouped-list corner (as in Settings).
        static let card: CGFloat = 26
    }

    /// Minimum tap target (HIG).
    static let minTapTarget: CGFloat = 44

    /// Single-colour tokens that are not part of a tone pair.
    enum Palette {
        // `highlightMint` (text highlight) is declared in RichNoteEditor.swift.
    }
}

// MARK: - Tones

/// A card / pill colour pair, built like Material 3 container + on-container colours.
///
/// Light mode: `fill` is a very pale tint, `ink` a deep tone of the same hue (tinted cards are fine on white).
///
/// Dark mode follows iOS Settings, not tinted cards:
/// - `fill` is the SAME neutral raised surface for every tone (#1C1C1E, no hue). Cards, rows and sticky notes sit on it.
/// - `pillFill` is the next surface up (#2C2C2E) for pills, chips, secondary buttons and icon tiles, so they stay
///   visible on top of a card.
/// - `ink` is a light tonal colour (Material tone 80) of the tone's hue, for SMALL accents only: icons, tiny labels.
///   Never use it for card titles or body text; use `onSurface` / `onSurfaceVariant` for those.
///
/// Contrast (WCAG, computed from the asset values, see docs/DESIGN-SYSTEM.md): every dark `ink` is at least 7.7:1 on
/// #1C1C1E and 6.3:1 on #2C2C2E; every light `ink` is at least 7.3:1 on its fill.
///
/// Teal is the accent-adjacent family. As a tone it is for tinted pills and cards that relate to the app's identity;
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

    /// Container colour for cards and sticky notes: pale tint in light mode, neutral #1C1C1E in dark mode.
    var fill: Color { Color(assetPrefix + "Fill") }

    /// Small-accent colour (icon, tiny label, dot): deep tone in light mode, light tonal colour in dark mode.
    /// On `fill` it is for icons and short labels; for titles and body text use `onSurface`.
    var ink: Color { Color(assetPrefix + "Ink") }

    /// Container colour for things that sit ON a card or the page: pills, chips, secondary buttons, icon tiles.
    /// Same as `fill` in light mode; the lighter neutral #2C2C2E in dark mode.
    var pillFill: Color {
        let name = assetPrefix + "Fill"
        return Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 44 / 255, green: 44 / 255, blue: 46 / 255, alpha: 1)
            }
            return UIColor(named: name)?.resolvedColor(with: traits) ?? .secondarySystemBackground
        })
    }

    /// Strong text on `fill` (Material "on-surface"): `ink` in light mode, primary white in dark mode.
    /// Use it for card titles and headings placed on a tone card.
    var onSurface: Color {
        let name = assetPrefix + "Ink"
        return Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark { return .label }
            return UIColor(named: name)?.resolvedColor(with: traits) ?? .label
        })
    }

    /// Quieter text on `fill` (Material "on-surface-variant"): ink at 85% in light mode (at least 5.1:1),
    /// system secondary grey (#98989F, 5.9:1 on #1C1C1E) in dark mode.
    var inkSecondary: Color {
        let name = assetPrefix + "Ink"
        return Color(UIColor { traits in
            if traits.userInterfaceStyle == .dark { return .secondaryLabel }
            return (UIColor(named: name)?.resolvedColor(with: traits) ?? .label).withAlphaComponent(0.85)
        })
    }

    /// Colour for a swatch or dot that has to show WHICH tone this is (colour pickers, calendar marks):
    /// the pale `fill` in light mode, the tonal `ink` in dark mode (where `fill` is the same grey for every tone).
    var swatch: Color {
        let fillName = assetPrefix + "Fill"
        let inkName = assetPrefix + "Ink"
        return Color(UIColor { traits in
            let name = traits.userInterfaceStyle == .dark ? inkName : fillName
            return UIColor(named: name)?.resolvedColor(with: traits) ?? .secondarySystemBackground
        })
    }

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

    /// Pale fill in light mode, neutral raised surface in dark mode. Use `.primary` text on top.
    var color: Color { tone.fill }

    /// Small-accent colour for icons and labels on this note colour.
    var ink: Color { tone.ink }

    /// Colour for a picker swatch or dot: shows the real hue in both modes (see `Tone.swatch`).
    var swatch: Color { tone.swatch }
}

// MARK: - Fonts

/// Registers the bundled fonts for this process. Call once at launch (`SelahApp.init`); no Info.plist entry needed.
///
/// DM Sans (UI text) and Space Grotesk (headings, numbers) are variable fonts under the SIL Open Font License
/// (licences next to the files in `Selah/Resources/Fonts`).
enum FontRegistry {
    /// File names (without extension) of the bundled fonts.
    static let fileNames = ["DMSans", "DMSans-Italic", "SpaceGrotesk"]

    /// True once `registerAll()` has run and at least one font file was found in the bundle.
    static var fontFilesAvailable: Bool {
        fileNames.contains { url(for: $0) != nil }
    }

    static func registerAll() {
        _ = registered
    }

    private static let registered: Bool = {
        var found = false
        for file in FontRegistry.fileNames {
            guard let url = FontRegistry.url(for: file) else { continue }
            // Registering twice returns an "already registered" error, which is fine.
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            found = true
        }
        return found
    }()

    private static func url(for file: String) -> URL? {
        Bundle.main.url(forResource: file, withExtension: "ttf")
            ?? Bundle.main.url(forResource: file, withExtension: "ttf", subdirectory: "Fonts")
    }
}

/// Resolved font family names. The fonts are variable, and CoreText may expose the family as "DM Sans" or as the
/// file's name-table family ("DM Sans 9pt", "Space Grotesk Light"), so each family tries its known names and uses
/// the first one that resolves. Registration must happen first (`FontRegistry.registerAll()` in `SelahApp.init`).
enum SelahFontFamily {
    /// DM Sans: body text, labels, buttons, pills, verses.
    static let body: String = resolve(["DM Sans", "DM Sans 9pt", "DMSans-9ptRegular"])
    /// Space Grotesk: display, headings, titles, numbers.
    static let display: String = resolve(["Space Grotesk", "Space Grotesk Light", "SpaceGrotesk-Light"])

    private static func resolve(_ candidates: [String]) -> String {
        FontRegistry.registerAll()
        return candidates.first { UIFont(name: $0, size: 12) != nil } ?? candidates[0]
    }
}

// MARK: - Typography

/// Type scale in the spirit of Material 3 (display / headline / title / body / label), kept small and calm.
/// Every token is `Font.custom(_:size:relativeTo:)`, so it scales with Dynamic Type from the base size below.
///
/// | Token | Face | Base | Weight | Scales like |
/// |---|---|---|---|---|
/// | selahDisplay | Space Grotesk | 28 | semibold | largeTitle |
/// | selahTitle | Space Grotesk | 20 | semibold | title2 |
/// | selahCardTitle | Space Grotesk | 17 | semibold | headline |
/// | selahHeadline | Space Grotesk | 16 | semibold | callout |
/// | selahVerseLarge | DM Sans | 19 | regular | body |
/// | selahVerse | DM Sans | 17 | regular | body |
/// | selahVerseCompact | DM Sans | 16 | regular | callout |
/// | selahBody | DM Sans | 16 | regular | body |
/// | selahButton | DM Sans | 16 | semibold | body |
/// | selahLabel | DM Sans | 14 | medium | subheadline |
/// | selahLabelSmall | DM Sans | 13 | medium | footnote |
/// | selahEyebrow | DM Sans | 12 | semibold | caption |
/// | selahStatLarge / Stat / StatSmall | Space Grotesk | 28 / 22 / 14 | semibold, tabular digits | largeTitle / title2 / subheadline |
///
/// Weights are always set explicitly: Space Grotesk's default instance is Light.
extension Font {
    private static func grotesk(_ size: CGFloat, _ style: Font.TextStyle, _ weight: Font.Weight) -> Font {
        .custom(SelahFontFamily.display, size: size, relativeTo: style).weight(weight)
    }

    private static func dmSans(_ size: CGFloat, _ style: Font.TextStyle, _ weight: Font.Weight) -> Font {
        .custom(SelahFontFamily.body, size: size, relativeTo: style).weight(weight)
    }

    /// Page title in the content area (for example the Today greeting): Space Grotesk 28 semibold.
    static var selahDisplay: Font { grotesk(28, .largeTitle, .semibold) }
    /// Section heading: Space Grotesk 20 semibold.
    static var selahTitle: Font { grotesk(20, .title2, .semibold) }
    /// Card heading: Space Grotesk 17 semibold.
    static var selahCardTitle: Font { grotesk(17, .headline, .semibold) }
    /// Small heading, for example a book name in a row: Space Grotesk 16 semibold.
    static var selahHeadline: Font { grotesk(16, .callout, .semibold) }
    /// Scripture text, reading size: DM Sans 17 regular.
    static var selahVerse: Font { dmSans(17, .body, .regular) }
    /// Hero scripture text, for example verse of the day: DM Sans 19 regular.
    static var selahVerseLarge: Font { dmSans(19, .body, .regular) }
    /// Compact scripture text in lists and cards: DM Sans 16 regular.
    static var selahVerseCompact: Font { dmSans(16, .callout, .regular) }
    /// Stat number, large: Space Grotesk 28 semibold, tabular digits.
    static var selahStatLarge: Font { grotesk(28, .largeTitle, .semibold).monospacedDigit() }
    /// Stat number: Space Grotesk 22 semibold, tabular digits.
    static var selahStat: Font { grotesk(22, .title2, .semibold).monospacedDigit() }
    /// Small stat number, for example inside a pill or a ring: Space Grotesk 14 semibold, tabular digits.
    static var selahStatSmall: Font { grotesk(14, .subheadline, .semibold).monospacedDigit() }
    /// Small caps-style label above a group: DM Sans 12 semibold. Pair with `.selahEyebrow()`.
    static var selahEyebrow: Font { dmSans(12, .caption, .semibold) }
    /// Running text: DM Sans 16 regular.
    static var selahBody: Font { dmSans(16, .body, .regular) }
    /// Secondary text, chips, secondary and tertiary buttons: DM Sans 14 medium. Add `.weight(.semibold)` when needed.
    static var selahLabel: Font { dmSans(14, .subheadline, .medium) }
    /// Smallest label (small pills, captions): DM Sans 13 medium.
    static var selahLabelSmall: Font { dmSans(13, .footnote, .medium) }
    /// Primary button label: DM Sans 16 semibold.
    static var selahButton: Font { dmSans(16, .body, .semibold) }
}

extension View {
    /// Eyebrow label: DM Sans 12 semibold, uppercase, slightly tracked, secondary colour.
    /// Use it to name a group of content (for example "NEXT GATHERING"), not above every heading.
    func selahEyebrow() -> some View {
        self
            .font(.selahEyebrow)
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(.secondary)
    }
}

/// Space Grotesk large and inline titles in navigation bars.
///
/// SwiftUI has no API for the navigation title font, so this configures the UIKit appearance proxy once at app start.
/// Only the title text attributes are touched, so the iOS 26 Liquid Glass bar and scroll-edge effect are untouched.
/// The fonts are built with `UIFontMetrics`, so they honour the Dynamic Type size in force when the bar is created.
enum NavigationAppearance {
    /// Large title base size (scales like `.largeTitle`) and inline title base size (scales like `.headline`).
    static let largeTitleSize: CGFloat = 30
    static let inlineTitleSize: CGFloat = 17

    @MainActor
    static func install() {
        let large = groteskFont(size: largeTitleSize, weight: .semibold, style: .largeTitle)
        let inline = groteskFont(size: inlineTitleSize, weight: .semibold, style: .headline)

        let appearance = UINavigationBarAppearance()
        appearance.largeTitleTextAttributes = [.font: large]
        appearance.titleTextAttributes = [.font: inline]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.compactAppearance = appearance

        // UIKit pieces (text view caret/selection, bar buttons, tab bar) use the accent too.
        if let accent = UIColor(named: "AccentColor") {
            UIView.appearance().tintColor = accent
            UITabBar.appearance().tintColor = accent
        }
        // scrollEdgeAppearance is left nil on purpose: UIKit then derives it from `standardAppearance`
        // with the transparent large-title background, keeping the title attributes.
    }

    /// Space Grotesk at an explicit weight, scaled with Dynamic Type like `style`.
    /// Falls back to the system font if the font is not registered (previews, tests without the bundle).
    static func groteskFont(size: CGFloat, weight: UIFont.Weight, style: UIFont.TextStyle) -> UIFont {
        let base = variableFont(family: SelahFontFamily.display, size: size, weight: weight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }

    /// Kept for callers written for the old serif titles (the note editor's heading style).
    /// Now returns Space Grotesk, scaled with Dynamic Type like `style`.
    static func serifFont(for style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont {
        let size: CGFloat
        switch style {
        case .largeTitle: size = 28
        case .title1: size = 24
        case .title2: size = 20
        case .title3: size = 18
        default: size = 17
        }
        return groteskFont(size: size, weight: weight, style: style)
    }

    /// A variable font with its weight axis set. The `wght` axis tag is 0x77676874.
    private static func variableFont(family: String, size: CGFloat, weight: UIFont.Weight) -> UIFont {
        guard let base = UIFont(name: family, size: size) else {
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        let axisWeight: Double
        switch weight {
        case .ultraLight, .thin, .light: axisWeight = 300
        case .regular: axisWeight = 400
        case .medium: axisWeight = 500
        case .semibold: axisWeight = 600
        default: axisWeight = 700
        }
        let weightAxis = NSNumber(value: 0x7767_6874)
        let variation = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = base.fontDescriptor.addingAttributes([
            variation: [weightAxis: NSNumber(value: axisWeight)]
        ])
        return UIFont(descriptor: descriptor, size: size)
    }
}

#Preview("Tones") {
    ScrollView {
        VStack(spacing: Theme.Spacing.xs) {
            ForEach(Tone.allCases, id: \.self) { tone in
                HStack {
                    Text(tone.name)
                        .font(.selahHeadline)
                        .foregroundStyle(tone.onSurface)
                    Spacer()
                    Text("On surface")
                        .font(.selahLabel)
                        .foregroundStyle(tone.inkSecondary)
                    Circle().fill(tone.ink).frame(width: 12, height: 12)
                    Text("Pill")
                        .font(.selahLabelSmall)
                        .foregroundStyle(tone.ink)
                        .padding(.horizontal, Theme.Spacing.s)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(tone.pillFill, in: Capsule())
                }
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
        Text("Row heading").font(.selahHeadline)
        Text("The Lord is my shepherd; I shall not want.").font(.selahVerseLarge)
        Text("The Lord is my shepherd; I shall not want.").font(.selahVerse)
        Text("Body text in DM Sans.").font(.selahBody)
        Text("Label").font(.selahLabel)
        Text("Next gathering").selahEyebrow()
        Text("1,234").font(.selahStat)
        Button("Button") {}.buttonStyle(.selahPrimary)
    }
    .padding(Theme.Spacing.m)
}

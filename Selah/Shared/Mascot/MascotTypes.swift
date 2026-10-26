import SwiftUI
import UIKit

// The Selah mascot: a soft plush cloud blob with two glossy eyes. This file holds the plain types (colour modes,
// moods, activities, asset naming). The drawing is in MascotView.swift, the rounded tile in MascotTile.swift.
// Docs and the naming of drop-in PNGs: docs/DESIGN-SYSTEM.md, section "Mascot".

// MARK: - Palette helpers

/// Colours used by the mascot drawing. The mascot is an accent element, so it keeps its own colours in dark mode.
enum MascotPalette {
    /// Eyes, brows and mouth: near-black graphite.
    static let ink = Color(red: 0.11, green: 0.11, blue: 0.13)
    /// Accessories (headset, book cover, pencil tip, "z"): graphite in light mode, a lighter grey in dark mode so it
    /// still shows over a black page.
    static let graphite = dynamic(light: 0x3C3D44, dark: 0x9A9BA3)
    /// Heart cheeks (the "loved" mood): a warm rose.
    static let heart = Color(red: 0.89, green: 0.38, blue: 0.50)
    /// Tears and sweat drops: a soft sky blue (blue is allowed for the mascot).
    static let droplet = Color(red: 0.55, green: 0.78, blue: 0.96)

    /// A colour with a light and a dark variant, from 0xRRGGBB values.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            ui(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func ui(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Colour mode

/// The mascot's body colour. The user picks one in Settings (`@AppStorage("mascotMode")`); the app icon will follow it.
/// Blue, yellow and green are allowed here (owner's choice); purple, violet, lavender and indigo are never used.
enum MascotMode: String, CaseIterable, Codable, Sendable {
    case coral
    case sky
    case sunshine
    case leaf
    case peach
    case sand

    /// `@AppStorage` key for the chosen mode. The raw value is stored (default "coral").
    static let storageKey = "mascotMode"

    /// The default mode.
    static let standard = MascotMode.coral

    /// The mode for a stored raw value; unknown or empty values give the default.
    init(storedValue: String) {
        self = MascotMode(rawValue: storedValue) ?? .standard
    }

    /// Plain-word name for pickers and VoiceOver.
    var name: String {
        switch self {
        case .coral: return "Coral"
        case .sky: return "Sky"
        case .sunshine: return "Sunshine"
        case .leaf: return "Leaf"
        case .peach: return "Peach"
        case .sand: return "Sand"
        }
    }

    /// Light body colour (top-left of the gradient).
    var body: Color {
        switch self {
        case .coral: return MascotPalette.dynamic(light: 0xF8BFC1, dark: 0xF6A3A6)
        case .sky: return MascotPalette.dynamic(light: 0xB5DAF7, dark: 0x9BCBF0)
        case .sunshine: return MascotPalette.dynamic(light: 0xF9E0A0, dark: 0xF5D283)
        case .leaf: return MascotPalette.dynamic(light: 0xB5E3BF, dark: 0x9AD6A8)
        case .peach: return MascotPalette.dynamic(light: 0xF9D5C7, dark: 0xF6C2AE)
        case .sand: return MascotPalette.dynamic(light: 0xEEDFC9, dark: 0xE8D2B1)
        }
    }

    /// Deeper body colour (bottom of the gradient, shading).
    var bodyDeep: Color {
        switch self {
        case .coral: return MascotPalette.dynamic(light: 0xF28A8E, dark: 0xE56E74)
        case .sky: return MascotPalette.dynamic(light: 0x8EC5F2, dark: 0x6FAEE0)
        case .sunshine: return MascotPalette.dynamic(light: 0xF6D27A, dark: 0xE4BA55)
        case .leaf: return MascotPalette.dynamic(light: 0x8FD19E, dark: 0x6FBF82)
        case .peach: return MascotPalette.dynamic(light: 0xF4BAA6, dark: 0xE99F88)
        case .sand: return MascotPalette.dynamic(light: 0xE3C9A8, dark: 0xD0AE87)
        }
    }

    /// The rosy blush on the lower body.
    var blush: Color {
        switch self {
        case .coral: return MascotPalette.dynamic(light: 0xE8667A, dark: 0xE8667A)
        case .sky: return MascotPalette.dynamic(light: 0xF2A0A8, dark: 0xEE98A2)
        case .sunshine: return MascotPalette.dynamic(light: 0xF2A07A, dark: 0xEE9570)
        case .leaf: return MascotPalette.dynamic(light: 0xF2A0A0, dark: 0xEE9898)
        case .peach: return MascotPalette.dynamic(light: 0xEE8F8C, dark: 0xEA8683)
        case .sand: return MascotPalette.dynamic(light: 0xE6A08F, dark: 0xE29A8A)
        }
    }

    /// A single colour for a dot or swatch that shows which mode this is.
    var swatch: Color { bodyDeep }

    /// Name of the alternate app icon for this mode (listed in project.yml), or nil for the default icon.
    var appIconName: String? {
        switch self {
        case .coral: return nil
        case .sky: return "AppIcon-Sky"
        case .sunshine: return "AppIcon-Sunshine"
        case .leaf: return "AppIcon-Leaf"
        case .peach: return "AppIcon-Peach"
        case .sand: return "AppIcon-Sand"
        }
    }
}

// MARK: - Mood

/// How the eyes are drawn.
enum MascotEyeStyle: Sendable {
    /// Glossy black ovals.
    case open
    /// Bigger glossy ovals (loved).
    case bigOpen
    /// Happy arcs, curved upwards (joyful).
    case happyArc
    /// Closed, relaxed arcs, curved downwards (peaceful).
    case closedCurve
    /// Soft half-closed, shining eyes (grateful).
    case softHalf
    /// Heavy half-closed lids (tired).
    case heavyLid
    /// Round eyes with the pupils low (sad).
    case lookDown
    /// Wide eyes with small pupils (anxious).
    case wide
    /// Narrowed eyes (angry).
    case narrow
}

enum MascotBrowStyle: Sendable {
    case none
    /// Inner ends raised a little (sad).
    case sad
    /// Raised and tilted more (anxious).
    case worried
    /// Angled down into a V (angry).
    case angry
}

enum MascotMouthStyle: Sendable {
    case none
    case smile
    case smallSmile
    case frown
    /// A short, tight frown (angry).
    case tightFrown
    case wobble
    /// A wide open smile (joyful).
    case wideOpen
    /// A flat, slightly open mouth (tired).
    case flat
}

/// A small extra on the face that carries the mood.
enum MascotExtra: Sendable {
    case none
    /// Rosy cheeks (joyful).
    case cheeks
    /// A tiny sparkle by the cheek (grateful).
    case sparkle
    /// Two small hearts by the cheeks (loved).
    case hearts
    /// A faint "z" (tired).
    case sleepyZ
    /// One small tear (sad).
    case tear
    /// A tiny sweat drop (anxious).
    case sweat
    /// A slightly flushed face (angry).
    case flush
}

/// The eight moods of the daily check-in.
enum MascotMood: String, CaseIterable, Codable, Sendable {
    case joyful
    case peaceful
    case grateful
    case loved
    case tired
    case sad
    case anxious
    case angry

    /// "Joyful", "Peaceful", ...
    var title: String {
        switch self {
        case .joyful: return "Joyful"
        case .peaceful: return "Peaceful"
        case .grateful: return "Grateful"
        case .loved: return "Loved"
        case .tired: return "Tired"
        case .sad: return "Sad"
        case .anxious: return "Anxious"
        case .angry: return "Angry"
        }
    }

    var eyes: MascotEyeStyle {
        switch self {
        case .joyful: return .happyArc
        case .peaceful: return .closedCurve
        case .grateful: return .softHalf
        case .loved: return .bigOpen
        case .tired: return .heavyLid
        case .sad: return .lookDown
        case .anxious: return .wide
        case .angry: return .narrow
        }
    }

    var brows: MascotBrowStyle {
        switch self {
        case .sad: return .sad
        case .anxious: return .worried
        case .angry: return .angry
        default: return .none
        }
    }

    var mouth: MascotMouthStyle {
        switch self {
        case .joyful: return .wideOpen
        case .peaceful: return .smallSmile
        case .grateful: return .smile
        case .loved: return .smallSmile
        case .tired: return .flat
        case .sad: return .frown
        case .anxious: return .wobble
        case .angry: return .tightFrown
        }
    }

    var extra: MascotExtra {
        switch self {
        case .joyful: return .cheeks
        case .peaceful: return .none
        case .grateful: return .sparkle
        case .loved: return .hearts
        case .tired: return .sleepyZ
        case .sad: return .tear
        case .anxious: return .sweat
        case .angry: return .flush
        }
    }

    /// The mood `delta` steps along the list, wrapping around at both ends.
    func shifted(by delta: Int) -> MascotMood {
        let all = MascotMood.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        let count = all.count
        let next = ((index + delta) % count + count) % count
        return all[next]
    }
}

// MARK: - Activity

/// What the mascot is doing: a simple accessory drawn on top of it.
enum MascotActivity: String, CaseIterable, Sendable {
    case neutral
    /// Headset: Songs.
    case headset
    /// Open book: Study notes.
    case reading
    /// Joined hands: Service notes.
    case praying
    /// Pencil: Personal notes.
    case writing
    /// Raised arm: greetings.
    case waving
    /// Closed eyes and a "z": empty states.
    case sleeping
}

// MARK: - Drop-in artwork

/// Final raster artwork replaces the drawn mascot with no code change: add an image set with the right name to the
/// asset catalog and `MascotView` shows it.
///
/// - An activity image: `Mascot-<activity>-<mode>`, for example `Mascot-headset-sky`, `Mascot-neutral-coral`.
///   Used when no mood is set.
/// - A mood image: `Mascot-mood-<mood>-<mode>`, for example `Mascot-mood-joyful-coral`.
///   Used when a mood is set and the activity is `.neutral`.
/// - Any other combination (a mood with an activity) is drawn.
enum MascotImages {
    /// The asset name to look for, or nil when the combination is always drawn.
    static func assetName(activity: MascotActivity, mood: MascotMood?, mode: MascotMode) -> String? {
        if let mood {
            guard activity == .neutral else { return nil }
            return "Mascot-mood-\(mood.rawValue)-\(mode.rawValue)"
        }
        return "Mascot-\(activity.rawValue)-\(mode.rawValue)"
    }

    /// The delivered image when the asset catalog has one.
    static func image(activity: MascotActivity, mood: MascotMood?, mode: MascotMode) -> UIImage? {
        guard let name = assetName(activity: activity, mood: mood, mode: mode) else { return nil }
        return UIImage(named: name)
    }
}

/// Whether the mascot may animate. Off for UI-test launches so screenshots are still and the app can go idle.
enum MascotMotion {
    static let allowed: Bool = !LaunchOptions.current.usesTestStore
}

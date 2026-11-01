import SwiftUI
import UIKit

/// The app's accent follows Selah's colour (owner, 1 Nov: deep shades). Each mode has a deep accent that carries
/// white text at 4.5:1 or more in light mode, a lighter accent with dark text in dark mode, and the quiet container and
/// ink pair used by secondary buttons. `Theme.accent`, `onAccent`, `brandFill` and `brandInk` read these.
///
/// | Mode | Light accent | White on it | Dark accent |
/// |---|---|---|---|
/// | Coral | #D33E43 | 4.6:1 | #E2585D |
/// | Sky | #2E6DB4 | 5.3:1 | #6BA3E0 |
/// | Sunshine (burnt orange, never gold) | #B05608 | 5.0:1 | #E58A3C |
/// | Leaf | #2E7D4F | 5.0:1 | #5BB07E |
/// | Peach (terracotta) | #C0533A | 4.6:1 | #E27A61 |
/// | Sand (caramel) | #8A6238 | 5.4:1 | #C29462 |
enum AccentPalette {
    struct Shades: Sendable {
        let accent: UInt32
        let darkAccent: UInt32
        /// Text on `darkAccent` (white would be too faint on the lighter dark-mode accents).
        let onDarkAccent: UInt32
        let fill: UInt32
        let ink: UInt32
        let darkInk: UInt32
    }

    /// Posted when the accent should be re-applied (Settings closed, onboarding finished). The root rebuilds then,
    /// so every screen picks up the new colour at once.
    static let refresh = Notification.Name("SelahAccentRefresh")

    /// The mode stored by the mascot colour picker.
    static var current: MascotMode {
        MascotMode(storedValue: UserDefaults.standard.string(forKey: MascotMode.storageKey) ?? "")
    }

    static func shades(for mode: MascotMode) -> Shades {
        switch mode {
        case .coral:
            return Shades(accent: 0xD33E43, darkAccent: 0xE2585D, onDarkAccent: 0x2A0004,
                          fill: 0xFBE9EA, ink: 0xA42A2F, darkInk: 0xFFB3B1)
        case .sky:
            return Shades(accent: 0x2E6DB4, darkAccent: 0x6BA3E0, onDarkAccent: 0x001A33,
                          fill: 0xE6EEF8, ink: 0x1F4F86, darkInk: 0xB5D3F5)
        case .sunshine:
            return Shades(accent: 0xB05608, darkAccent: 0xE58A3C, onDarkAccent: 0x2A1200,
                          fill: 0xFBEEE2, ink: 0x8F4506, darkInk: 0xFFC79A)
        case .leaf:
            return Shades(accent: 0x2E7D4F, darkAccent: 0x5BB07E, onDarkAccent: 0x00210F,
                          fill: 0xE5F2EA, ink: 0x1F5C39, darkInk: 0xA5DDBA)
        case .peach:
            return Shades(accent: 0xC0533A, darkAccent: 0xE27A61, onDarkAccent: 0x2A0A03,
                          fill: 0xF9EAE5, ink: 0x8E3A27, darkInk: 0xFFBFAE)
        case .sand:
            return Shades(accent: 0x8A6238, darkAccent: 0xC29462, onDarkAccent: 0x241505,
                          fill: 0xF3ECE3, ink: 0x6A4A28, darkInk: 0xE6C9A6)
        }
    }

    /// A colour that follows the current mode and the light or dark appearance.
    static func dynamic(light: @escaping @Sendable (Shades) -> UInt32, dark: @escaping @Sendable (Shades) -> UInt32) -> Color {
        Color(UIColor { traits in
            let shades = shades(for: current)
            return uiColor(traits.userInterfaceStyle == .dark ? dark(shades) : light(shades))
        })
    }

    static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

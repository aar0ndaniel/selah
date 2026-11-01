import Foundation
import Testing
@testable import Selah

struct AccentPaletteTests {
    private func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF) + 0.7152 * channel((hex >> 8) & 0xFF) + 0.0722 * channel(hex & 0xFF)
    }

    private func contrast(_ a: UInt32, _ b: UInt32) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test(arguments: MascotMode.allCases)
    func whiteTextIsReadableOnTheLightAccent(_ mode: MascotMode) {
        #expect(contrast(AccentPalette.shades(for: mode).accent, 0xFFFFFF) >= 4.5)
    }

    @Test(arguments: MascotMode.allCases)
    func darkModeTextIsReadableOnTheDarkAccent(_ mode: MascotMode) {
        let shades = AccentPalette.shades(for: mode)
        #expect(contrast(shades.darkAccent, shades.onDarkAccent) >= 4.5)
    }

    @Test(arguments: MascotMode.allCases)
    func inkIsReadableOnItsContainer(_ mode: MascotMode) {
        let shades = AccentPalette.shades(for: mode)
        #expect(contrast(shades.ink, shades.fill) >= 4.5)
        #expect(contrast(shades.darkInk, 0x2C2C2E) >= 4.5)
    }

    @Test func coralKeepsTheOriginalBrandRed() {
        #expect(AccentPalette.shades(for: .coral).accent == 0xD33E43)
        #expect(AccentPalette.shades(for: .coral).darkAccent == 0xE2585D)
    }
}

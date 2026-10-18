import Testing
import UIKit
@testable import Selah

/// The bundled fonts must resolve by name after registration. Skipped when the font files are not in the test host's
/// main bundle (for example a logic-only test run), since there is then nothing to register.
struct FontTests {
    @Test(.enabled(if: FontRegistry.fontFilesAvailable))
    func bundledFontsResolveAfterRegistration() {
        FontRegistry.registerAll()
        #expect(UIFont(name: SelahFontFamily.body, size: 16) != nil)
        #expect(UIFont(name: SelahFontFamily.display, size: 28) != nil)
    }

    @Test func navigationTitleFontAlwaysResolves() {
        // Falls back to the system font when the family is unavailable, never crashes.
        let font = NavigationAppearance.groteskFont(size: 17, weight: .semibold, style: .headline)
        #expect(font.pointSize > 0)
    }
}

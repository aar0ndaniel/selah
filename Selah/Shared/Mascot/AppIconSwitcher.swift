import UIKit

/// Switches the home screen icon to match the mascot colour. iOS shows its own short notice when the icon changes.
@MainActor
enum AppIconSwitcher {
    static func apply(_ mode: MascotMode) {
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.alternateIconName != mode.appIconName else { return }
        app.setAlternateIconName(mode.appIconName) { _ in }
    }
}

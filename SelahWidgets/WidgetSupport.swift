import CoreText
import SwiftUI
import UIKit
import WidgetKit

// Shared pieces for the Selah home screen widgets: the timeline provider, fonts, colours and mascot art lookup.
// The look follows the app: DM Sans text, Space Grotesk numbers and titles, red accent #D33E43, plain white or black
// backgrounds, colour only in the streak card, the mascot and small accents.

// MARK: - Timeline

struct SelahEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

/// One provider for all three widgets: the snapshot the app wrote, redrawn at each midnight it covers.
struct SelahProvider: TimelineProvider {
    func placeholder(in context: Context) -> SelahEntry {
        SelahEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (SelahEntry) -> Void) {
        let stored = WidgetStore.load()
        completion(SelahEntry(date: Date(), snapshot: context.isPreview ? (stored ?? .sample) : stored))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SelahEntry>) -> Void) {
        let now = Date()
        let snapshot = WidgetStore.load()
        let midnights = WidgetDisplay.refreshDates(in: snapshot, after: now)
        let entries = [SelahEntry(date: now, snapshot: snapshot)]
            + midnights.map { SelahEntry(date: $0, snapshot: snapshot) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Fonts

/// Registers the bundled DM Sans and Space Grotesk for the widget process (the app does the same at launch).
enum WidgetFonts {
    static func register() {
        _ = registered
    }

    private static let registered: Bool = {
        for file in ["DMSans", "SpaceGrotesk"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        return true
    }()

    static let body = resolve(["DM Sans", "DM Sans 9pt", "DMSans-9ptRegular"])
    static let display = resolve(["Space Grotesk", "Space Grotesk Light", "SpaceGrotesk-Light"])

    private static func resolve(_ candidates: [String]) -> String {
        register()
        return candidates.first { UIFont(name: $0, size: 12) != nil } ?? candidates[0]
    }
}

extension Font {
    /// DM Sans at a base size, scaling with Dynamic Type like `style`.
    static func widgetText(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(WidgetFonts.body, size: size, relativeTo: style)
    }

    /// Space Grotesk at a base size, for numbers and titles.
    static func widgetDisplay(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(WidgetFonts.display, size: size, relativeTo: style)
    }
}

// MARK: - Colours

enum WidgetPalette {
    /// Selah red. Dark mode uses the lighter shade.
    static let accent = dynamic(light: 0xD33E43, dark: 0xE2585D)
    /// Hot pink of the streak flame and week row.
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.51)
    /// Dark ink on the pink "today" circle (about 5.7:1).
    static let ink = Color(red: 0.102, green: 0.078, blue: 0.086)

    // The streak card, matching the card on Today: soft pink in light mode, deep warm-neutral in dark mode.
    static let streakTop = dynamic(light: 0xFFF1F3, dark: 0x1A1416)
    static let streakBottom = dynamic(light: 0xFFEBEF, dark: 0x141012)
    /// "days streak": #C42A5C on the pink card (about 4.8:1), #FF7A94 on the dark card (about 6.5:1).
    static let streakLabel = dynamic(light: 0xC42A5C, dark: 0xFF7A94)
    static let numberTop = dynamic(light: 0xF0566E, dark: 0xFF8A80)
    static let numberBottom = dynamic(light: 0xE0336B, dark: 0xFF4F81)
    static let check = dynamic(light: 0xE0336B, dark: 0xFF8FA8)
    /// Black in light mode, white in dark mode; used at low opacity for day cells.
    static let faint = dynamic(light: 0x000000, dark: 0xFFFFFF)

    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

// MARK: - Mascot art

/// Looks up Selah's artwork by the same names the app uses. A colour mode without an image falls back to coral.
enum WidgetArt {
    static func mascot(mood: String?, mode: String) -> UIImage? {
        if let mood {
            return image("Mascot-mood-\(mood)-\(mode)") ?? image("Mascot-mood-\(mood)-coral")
        }
        return image("Mascot-neutral-\(mode)") ?? image("Mascot-neutral-coral")
    }

    static func mascot(activity: String, mode: String) -> UIImage? {
        image("Mascot-\(activity)-\(mode)") ?? image("Mascot-\(activity)-coral") ?? mascot(mood: nil, mode: mode)
    }

    /// The mascot holding the flame, when Selah's art for it is in the catalog for this colour. No coral fallback here:
    /// another colour draws the flame with its own mascot instead.
    static func streakBuddy(lit: Bool, mode: String) -> UIImage? {
        image("Streak-\(lit ? "lit" : "off")-\(mode)")
    }

    static func flame(lit: Bool) -> UIImage? {
        image(lit ? "StreakFlame" : "StreakFlameOff")
    }

    private static func image(_ name: String) -> UIImage? {
        UIImage(named: name)
    }
}

/// A Phosphor icon from the widget catalog, as a template image.
struct WidgetIcon: View {
    let name: String
    let size: CGFloat

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Sample data

extension WidgetSnapshot {
    /// Shown in the widget gallery and in previews.
    static var sample: WidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        // Monday of this week.
        let monday = calendar.date(byAdding: .day, value: -((weekday + 5) % 7), to: today) ?? today
        let week: [WidgetWeekCell] = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
            return WidgetWeekCell(date: date, state: date <= today ? "done" : "none", isToday: date == today)
        }
        var snapshot = WidgetSnapshot()
        snapshot.streakDays = [WidgetStreakDay(date: today, current: 5, best: 9, doneToday: true, week: week)]
        snapshot.verses = [
            WidgetVerse(
                date: today,
                text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.",
                reference: "Philippians 4:6 (KJV)",
                chosen: false
            )
        ]
        snapshot.moodRaw = "joyful"
        snapshot.moodDate = today
        return snapshot
    }
}

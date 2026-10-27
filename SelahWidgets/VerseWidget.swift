import SwiftUI
import WidgetKit

/// Verse of the day: the verse the user chose on Today, otherwise a well-loved passage that changes each day.
struct VerseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SelahVerse", provider: SelahProvider()) { entry in
            VerseWidgetView(entry: entry)
        }
        .configurationDisplayName("Verse of the day")
        .description("Today's verse on your home or lock screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct VerseWidgetView: View {
    let entry: SelahEntry
    @Environment(\.widgetFamily) private var family

    /// The verse the app shared for this day, or a built-in one so the widget is never empty.
    private var verse: WidgetVerse {
        WidgetDisplay.verse(in: entry.snapshot, on: entry.date) ?? WidgetFallbackVerses.verse(on: entry.date)
    }
    private var mode: String { entry.snapshot?.mascotMode ?? "coral" }

    var body: some View {
        content
            .widgetURL(URL(string: "selah://today"))
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    Color(.systemBackground)
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if family == .accessoryRectangular {
            rectangular
        } else {
            card(verse)
        }
    }

    // MARK: Home screen

    private var textSize: CGFloat {
        switch family {
        case .systemSmall: return 13
        case .systemLarge: return 18
        default: return 15
        }
    }

    private var lineLimit: Int {
        switch family {
        case .systemSmall: return 5
        case .systemLarge: return 11
        default: return 4
        }
    }

    private func card(_ verse: WidgetVerse) -> some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 10) {
            eyebrow
            Text(verse.text)
                .font(.widgetText(textSize, relativeTo: .body))
                .lineSpacing(family == .systemSmall ? 1 : 3)
                .foregroundStyle(.primary)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
            HStack(alignment: .bottom) {
                Text(verse.reference)
                    .font(.widgetText(12, relativeTo: .caption).weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if family == .systemLarge, let reading = WidgetArt.mascot(activity: "reading", mode: mode) {
                    Image(uiImage: reading)
                        .resizable()
                        .widgetAccentedRenderingMode(.desaturated)
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .accessibilityHidden(true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Verse of the day. \(verse.text) \(verse.reference)")
    }

    private var eyebrow: some View {
        HStack(spacing: 4) {
            WidgetIcon(name: "ph-sparkle-fill", size: 12)
                .foregroundStyle(WidgetPalette.accent)
                .widgetAccentable()
            Text(family == .systemSmall ? "Today" : "Verse of the day")
                .font(.widgetText(11, relativeTo: .caption2).weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Lock screen

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verse.reference)
                .font(.widgetText(13, relativeTo: .headline).weight(.semibold))
                .widgetAccentable()
                .lineLimit(1)
            Text(verse.text)
                .font(.widgetText(12, relativeTo: .caption))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Verse, medium", as: .systemMedium) {
    VerseWidget()
} timeline: {
    SelahEntry(date: Date(), snapshot: .sample)
}

#Preview("Verse, large", as: .systemLarge) {
    VerseWidget()
} timeline: {
    SelahEntry(date: Date(), snapshot: .sample)
}

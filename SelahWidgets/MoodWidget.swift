import SwiftUI
import WidgetKit

/// Today's mood: the mascot wearing it, or a nudge to answer "How are you feeling?" (opens the check-in).
struct MoodWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SelahMood", provider: SelahProvider()) { entry in
            MoodWidgetView(entry: entry)
        }
        .configurationDisplayName("Mood")
        .description("Your mascot in today's mood.")
        .supportedFamilies([.systemSmall])
    }
}

struct MoodWidgetView: View {
    let entry: SelahEntry

    private var mood: String? { WidgetDisplay.mood(in: entry.snapshot, on: entry.date) }
    private var mode: String { entry.snapshot?.mascotMode ?? "coral" }

    var body: some View {
        VStack(spacing: 6) {
            if let image = WidgetArt.mascot(mood: mood, mode: mode) {
                Image(uiImage: image)
                    .resizable()
                    .widgetAccentedRenderingMode(.desaturated)
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .accessibilityHidden(true)
            }
            if let mood {
                Text(mood.capitalized)
                    .font(.widgetDisplay(16, relativeTo: .headline).weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Today")
                    .font(.widgetText(11, relativeTo: .caption2))
                    .foregroundStyle(.secondary)
            } else {
                Text("How are you feeling?")
                    .font(.widgetText(13, relativeTo: .footnote).weight(.semibold))
                    .foregroundStyle(WidgetPalette.accent)
                    .multilineTextAlignment(.center)
                    .widgetAccentable()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mood.map { "Feeling \($0) today" } ?? "How are you feeling? Opens the check-in")
        .widgetURL(URL(string: mood == nil ? "selah://mood" : "selah://today"))
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}

#Preview("Mood", as: .systemSmall) {
    MoodWidget()
} timeline: {
    SelahEntry(date: Date(), snapshot: .sample)
    SelahEntry(date: Date(), snapshot: nil)
}

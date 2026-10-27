import SwiftUI
import WidgetKit

/// The streak the user shows on Today, with the mascot and the flame. Small: mascot, flame and number. Medium: the
/// same plus the week M to S. Lock screen: a flame and the number.
struct StreakWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SelahStreak", provider: SelahProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your study or service streak, with the mascot.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular])
    }
}

struct StreakWidgetView: View {
    let entry: SelahEntry
    @Environment(\.widgetFamily) private var family

    private var streak: WidgetStreakDisplay? { WidgetDisplay.streak(in: entry.snapshot, on: entry.date) }
    private var mode: String { entry.snapshot?.mascotMode ?? "coral" }

    var body: some View {
        content
            .widgetURL(URL(string: "selah://today"))
            .containerBackground(for: .widget) {
                if family == .accessoryCircular {
                    AccessoryWidgetBackground()
                } else {
                    LinearGradient(
                        colors: [WidgetPalette.streakTop, WidgetPalette.streakBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .systemMedium:
            if let streak { medium(streak) } else { openApp }
        default:
            if let streak { small(streak) } else { openApp }
        }
    }

    // MARK: Small

    private func small(_ streak: WidgetStreakDisplay) -> some View {
        VStack(spacing: 2) {
            StreakArtwork(lit: streak.lit, mode: mode)
                .frame(height: 72)
            number(streak.count, size: 30)
            label(streak)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(streak))
    }

    // MARK: Medium

    private func medium(_ streak: WidgetStreakDisplay) -> some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                StreakArtwork(lit: streak.lit, mode: mode)
                    .frame(height: 72)
                number(streak.count, size: 30)
                label(streak)
            }
            .frame(width: 112)

            VStack(alignment: .leading, spacing: 10) {
                Text(streak.doneToday ? "Done today" : "Not done yet today")
                    .font(.widgetText(13, relativeTo: .footnote).weight(.semibold))
                    .foregroundStyle(.primary)
                WidgetWeekRow(cells: streak.week)
                Text("Best \(streak.best)")
                    .font(.widgetText(12, relativeTo: .caption))
                    .foregroundStyle(WidgetPalette.faint.opacity(0.6))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken(streak))
    }

    // MARK: Lock screen

    private var circular: some View {
        VStack(spacing: 0) {
            WidgetIcon(name: "ph-flame-fill", size: 14)
            Text("\(streak?.count ?? 0)")
                .font(.widgetDisplay(20, relativeTo: .title3).weight(.bold))
                .monospacedDigit()
                .minimumScaleFactor(0.6)
        }
        .widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(streak.map(spoken) ?? "Streak")
    }

    // MARK: Pieces

    private func number(_ count: Int, size: CGFloat) -> some View {
        Text("\(count)")
            .font(.widgetDisplay(size, relativeTo: .largeTitle).weight(.bold))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(
                    colors: [WidgetPalette.numberTop, WidgetPalette.numberBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }

    private func label(_ streak: WidgetStreakDisplay) -> some View {
        Text("\(streak.count == 1 ? "day" : "days") streak \u{00B7} \(streak.kindTitle)")
            .font(.widgetText(12, relativeTo: .caption).weight(.semibold))
            .foregroundStyle(WidgetPalette.streakLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }

    private var openApp: some View {
        VStack(spacing: 6) {
            StreakArtwork(lit: false, mode: mode)
                .frame(height: 56)
            Text("Open Tehila to see your streak")
                .font(.widgetText(12, relativeTo: .caption).weight(.semibold))
                .foregroundStyle(WidgetPalette.streakLabel)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func spoken(_ streak: WidgetStreakDisplay) -> String {
        let days = streak.count == 1 ? "1 day" : "\(streak.count) days"
        return "\(streak.kindTitle) streak, \(days), best \(streak.best). \(streak.doneToday ? "Done today" : "Not done yet today")"
    }
}

/// The mascot holding the flame. Uses Selah's combined art when it is in the catalog, otherwise the flame with the
/// mascot standing in front of it (asleep next to a grey flame when the streak is 0).
struct StreakArtwork: View {
    let lit: Bool
    let mode: String

    var body: some View {
        if let buddy = WidgetArt.streakBuddy(lit: lit, mode: mode) {
            art(buddy)
        } else {
            GeometryReader { geo in
                let side = geo.size.height
                ZStack(alignment: .bottomLeading) {
                    if let flame = WidgetArt.flame(lit: lit) {
                        art(flame)
                            .frame(width: side, height: side)
                            .offset(x: side * 0.32)
                    }
                    if let mascot = lit
                        ? WidgetArt.mascot(mood: "joyful", mode: mode)
                        : WidgetArt.mascot(activity: "sleeping", mode: mode) {
                        art(mascot)
                            .frame(width: side * 0.66, height: side * 0.66)
                            .offset(x: -side * 0.08, y: side * 0.04)
                    }
                }
                .frame(width: geo.size.width, height: side)
            }
        }
    }

    private func art(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .widgetAccentedRenderingMode(.desaturated)
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

/// M T W T F S S with small circles: a check on done days, a pink ring for today while it is still open.
struct WidgetWeekRow: View {
    let cells: [WidgetWeekCell]

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    private let circle: CGFloat = 20

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.prefix(7).enumerated()), id: \.offset) { index, cell in
                VStack(spacing: 4) {
                    Text(Self.letters[index])
                        .font(.widgetText(10, relativeTo: .caption2).weight(cell.isToday ? .bold : .regular))
                        .foregroundStyle(WidgetPalette.faint.opacity(cell.isToday ? 1 : 0.6))
                    dot(cell)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func dot(_ cell: WidgetWeekCell) -> some View {
        switch cell.state {
        case "done":
            Circle()
                .fill(cell.isToday ? WidgetPalette.pink : WidgetPalette.pink.opacity(0.18))
                .frame(width: circle, height: circle)
                .overlay {
                    WidgetIcon(name: "ph-check", size: 11)
                        .foregroundStyle(cell.isToday ? WidgetPalette.ink : WidgetPalette.check)
                }
        case "pending":
            Circle()
                .strokeBorder(WidgetPalette.pink, lineWidth: 2)
                .frame(width: circle, height: circle)
        case "missed":
            Circle()
                .fill(WidgetPalette.faint.opacity(0.04))
                .frame(width: circle, height: circle)
        default:
            Circle()
                .fill(WidgetPalette.faint.opacity(cell.isToday ? 0.12 : 0.06))
                .frame(width: circle, height: circle)
        }
    }
}

#Preview("Streak, small", as: .systemSmall) {
    StreakWidget()
} timeline: {
    SelahEntry(date: Date(), snapshot: .sample)
}

#Preview("Streak, medium", as: .systemMedium) {
    StreakWidget()
} timeline: {
    SelahEntry(date: Date(), snapshot: .sample)
}

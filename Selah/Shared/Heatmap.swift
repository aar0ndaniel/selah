import SwiftUI

// Yearly activity heatmap card (GitHub-style): a header with an icon tile, a year switcher, a scrolling grid of
// rounded squares with five intensity levels, a "Log today" button and a streak / total footer.
//
// Colour: neutral card (secondarySystemBackground). The squares are opacities of one colour: the accent (red) by
// default, or a tone's ink. Level 0 is a quiet grey. Never gold, yellow, purple or indigo.
//
// Accessibility: the grid is one element with a summary. At accessibility text sizes it is replaced by a
// month-by-month list. Nothing animates, so Reduce Motion has nothing to turn off.

struct ActivityHeatmapCard: View {
    let title: String
    let subtitle: String
    let icon: PIcon
    /// nil draws the squares in the red accent.
    var tone: Tone? = nil
    /// One date per thing counted (one per study entry, one per service).
    let dates: [Date]
    /// Services: a day is either empty or full.
    var binary: Bool = false
    @Binding var year: Int
    var unitSingular: String = "note"
    var unitPlural: String = "notes"
    var streak: Int = 0
    var loggedToday: Bool = false
    /// nil hides the "Log today" button.
    var onLogToday: (() -> Void)? = nil
    var today: Date = Date()

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption2) private var cell: CGFloat = 13
    @ScaledMetric(relativeTo: .caption2) private var monthHeight: CGFloat = 14
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 44

    private let gap: CGFloat = 3
    private let monthGap: CGFloat = 4
    private static let levelOpacity: [Double] = [0, 0.3, 0.5, 0.75, 1]
    private static let weekdayLetters = ["M", "", "W", "", "F", "", ""]

    // MARK: Derived

    private var base: Color { tone?.ink ?? Theme.accent }
    private var tileFill: Color { tone?.fill ?? Theme.brandFill }
    private var tileInk: Color { tone?.ink ?? Theme.brandInk }

    private var currentYear: Int { Calendar.current.component(.year, from: today) }

    private var firstYear: Int {
        let years = dates.map { Calendar.current.component(.year, from: $0) }
        return min(years.min() ?? currentYear, currentYear)
    }

    private func plural(_ count: Int, _ singular: String, _ many: String) -> String {
        count == 1 ? "\(count) \(singular)" : "\(count) \(many)"
    }

    // MARK: Body

    var body: some View {
        let data = ActivityCalendar.year(year, dates: dates, today: today, binary: binary)
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                yearRow
                if typeSize.isAccessibilitySize {
                    monthList(data)
                } else {
                    grid(data)
                }
                if let onLogToday {
                    logButton(onLogToday)
                }
                footer(data)
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            PIconView(icon, filled: true, size: 22, relativeTo: .body)
                .foregroundStyle(tileInk)
                .frame(width: tile, height: tile)
                .background(tileFill, in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.selahCardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Year switcher and legend

    private var yearRow: some View {
        HStack(spacing: 0) {
            chevron(.caretLeft, label: "Previous year", enabled: year > firstYear) { year -= 1 }
            Text(String(year))
                .font(.headline)
                .monospacedDigit()
                .frame(minWidth: 52)
                .accessibilityLabel("Year \(String(year))")
            chevron(.caretRight, label: "Next year", enabled: year < currentYear) { year += 1 }
            Spacer(minLength: 0)
            if !typeSize.isAccessibilitySize {
                legend
            }
        }
    }

    private func chevron(_ icon: PIcon, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PIconView(icon, size: 18, relativeTo: .body)
                .foregroundStyle(Color.accentColor)
                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(color(level: level))
                    .frame(width: 10, height: 10)
            }
            Text("More")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    // MARK: Grid

    private func color(level: Int) -> Color {
        guard level > 0 else { return Color(.tertiarySystemFill) }
        let index = min(level, Self.levelOpacity.count - 1)
        return base.opacity(Self.levelOpacity[index])
    }

    private func grid(_ data: ActivityYear) -> some View {
        let step = cell + gap
        let width = max(CGFloat(data.weeks.count) * step - gap, 0)
        return HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            weekdayColumn
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    VStack(alignment: .leading, spacing: monthGap) {
                        ZStack(alignment: .topLeading) {
                            ForEach(data.monthLabels) { label in
                                Text(label.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fixedSize()
                                    .offset(x: CGFloat(label.weekIndex) * step)
                            }
                        }
                        .frame(width: width, height: monthHeight, alignment: .topLeading)

                        HStack(spacing: gap) {
                            ForEach(data.weeks) { week in
                                VStack(spacing: gap) {
                                    ForEach(week.days) { day in
                                        cellView(day)
                                    }
                                }
                                .id(week.id)
                            }
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onAppear { scrollToCurrent(proxy) }
                .onChange(of: year) { _, _ in scrollToCurrent(proxy) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary(data))
    }

    private var weekdayColumn: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Color.clear.frame(width: 1, height: monthHeight + monthGap)
            VStack(alignment: .trailing, spacing: gap) {
                ForEach(Array(Self.weekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .frame(height: cell)
                }
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func cellView(_ day: ActivityDay) -> some View {
        if day.isInYear {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(day.level == 0 && day.isFuture ? Color(.tertiarySystemFill).opacity(0.5) : color(level: day.level))
                .frame(width: cell, height: cell)
                .overlay {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.primary, lineWidth: 1.5)
                    }
                }
        } else {
            Color.clear.frame(width: cell, height: cell)
        }
    }

    /// Shows the current week at the trailing edge; a past year shows its December end.
    private func scrollToCurrent(_ proxy: ScrollViewProxy) {
        let data = ActivityCalendar.year(year, dates: [], today: today, binary: binary)
        let target = data.currentWeekIndex.flatMap { data.weeks.indices.contains($0) ? data.weeks[$0].id : nil }
            ?? data.weeks.last?.id
        guard let target else { return }
        proxy.scrollTo(target, anchor: .trailing)
    }

    // MARK: Month list (accessibility sizes)

    private func monthList(_ data: ActivityYear) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(data.months) { month in
                HStack(alignment: .firstTextBaseline) {
                    Text(month.title)
                    Spacer(minLength: Theme.Spacing.s)
                    Text(plural(month.count, unitSingular, unitPlural))
                        .monospacedDigit()
                        .foregroundStyle(month.count > 0 ? Color.primary : Color.secondary)
                }
                .font(.body)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(month.title): \(plural(month.count, unitSingular, unitPlural)) on \(plural(month.activeDays, "day", "days"))")
            }
        }
    }

    // MARK: Log today and footer

    private func logButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            PLabel(
                loggedToday ? "Done today" : "Log today",
                icon: loggedToday ? .check : .plus
            )
        }
        .buttonStyle(.selahPrimaryFull)
        .disabled(loggedToday)
        .accessibilityIdentifier("heatmap-log-today")
    }

    private func footer(_ data: ActivityYear) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Theme.Spacing.s))
        return layout {
            Text("Streak: \(plural(streak, "day", "days"))")
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
            }
            Text("Total (\(String(year))): \(plural(data.total, unitSingular, unitPlural))")
        }
        .font(.subheadline.weight(.semibold))
        .monospacedDigit()
        .accessibilityElement(children: .combine)
    }

    private func summary(_ data: ActivityYear) -> String {
        "\(title) activity \(String(year)): \(plural(data.activeDays, "day", "days")), "
            + "\(plural(data.total, unitSingular, unitPlural)). Current streak \(plural(streak, "day", "days"))"
    }
}

// MARK: - Preview

private struct HeatmapPreview: View {
    @State private var year = Calendar.current.component(.year, from: Date())
    var loggedToday = false

    private var dates: [Date] {
        let calendar = Calendar.current
        var result: [Date] = []
        for offset in 0..<200 where offset % 3 != 1 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
            result.append(day)
            if offset % 5 == 0 { result.append(day) }
            if offset % 7 == 0 { result.append(day); result.append(day) }
        }
        return result
    }

    var body: some View {
        ScrollView {
            ActivityHeatmapCard(
                title: "Reading",
                subtitle: "Read a little, even on busy days",
                icon: .bookOpen,
                dates: dates,
                year: $year,
                streak: 12,
                loggedToday: loggedToday,
                onLogToday: {}
            )
            .padding(Theme.Spacing.m)
        }
        .background(Color(.systemBackground))
    }
}

#Preview("Heatmap") {
    HeatmapPreview()
}

#Preview("Heatmap, done today") {
    HeatmapPreview(loggedToday: true)
}

#Preview("Heatmap, large text") {
    HeatmapPreview()
        .environment(\.dynamicTypeSize, .accessibility2)
}

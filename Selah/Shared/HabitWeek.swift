import SwiftUI

// Habit week: one row per habit (icon tile + name) with Monday to Sunday check circles. Consecutive done days are
// joined by a 4pt bar of the same colour behind the circles. Neutral card; colour only on the circles and tiles.
//
// - done: filled circle with a check
// - missed: hairline circle
// - pending (today, not done yet): ring in the habit colour
// - none (nothing due, or a day still to come): a small dim dot
// - today: an extra outer ring

struct HabitWeekRow: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: PIcon
    /// nil uses the red accent.
    let tone: Tone?
    let states: [WeekDayState]
}

struct HabitWeekCard: View {
    let rangeLabel: String
    /// Full weekday names, Monday first (for VoiceOver).
    let dayNames: [String]
    let todayIndex: Int?
    let rows: [HabitWeekRow]
    var canGoForward: Bool = false
    var canGoBack: Bool = true
    var onPrevious: () -> Void = {}
    var onNext: () -> Void = {}

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var circle: CGFloat = 28
    @ScaledMetric(relativeTo: .body) private var tile: CGFloat = 32

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    private let barHeight: CGFloat = 4

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                header
                letterRow
                ForEach(rows) { row in
                    rowView(row)
                }
            }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            Text(rangeLabel)
                .font(.headline)
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Week of \(rangeLabel)")
            Spacer(minLength: Theme.Spacing.s)
            chevron(.caretLeft, label: "Previous week", enabled: canGoBack, action: onPrevious)
            chevron(.caretRight, label: "Next week", enabled: canGoForward, action: onNext)
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

    // MARK: Rows

    private var letterRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.letters.enumerated()), id: \.offset) { index, letter in
                Text(letter)
                    .font(.footnote.weight(index == todayIndex ? .bold : .regular))
                    .foregroundStyle(index == todayIndex ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func rowView(_ row: HabitWeekRow) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                PIconView(row.icon, filled: true, size: 16, relativeTo: .body)
                    .foregroundStyle(tileInk(row))
                    .frame(width: tile, height: tile)
                    .background(tileFill(row), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                Text(row.title)
                    .font(.subheadline.weight(.semibold))
            }
            circles(row)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ActivityCalendar.rowSummary(title: row.title, states: row.states, dayNames: dayNames))
    }

    private func circles(_ row: HabitWeekRow) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(row.states.enumerated()), id: \.offset) { index, state in
                let previous = index > 0 ? row.states[index - 1] : WeekDayState.none
                let next = index + 1 < row.states.count ? row.states[index + 1] : WeekDayState.none
                dayCell(
                    state: state,
                    row: row,
                    joinLeft: state == .done && previous == .done,
                    joinRight: state == .done && next == .done,
                    isToday: index == todayIndex
                )
            }
        }
    }

    private func dayCell(state: WeekDayState, row: HabitWeekRow, joinLeft: Bool, joinRight: Bool, isToday: Bool) -> some View {
        let colour = doneColour(row)
        return ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(joinLeft ? colour : Color.clear).frame(height: barHeight)
                Rectangle().fill(joinRight ? colour : Color.clear).frame(height: barHeight)
            }
            circleView(state: state, colour: colour)
            if isToday {
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .frame(width: circle + 8, height: circle + 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: circle + 8)
    }

    @ViewBuilder
    private func circleView(state: WeekDayState, colour: Color) -> some View {
        switch state {
        case .done:
            Circle()
                .fill(colour)
                .frame(width: circle, height: circle)
                .overlay {
                    PIconView(.check, size: 14, relativeTo: .body)
                        .foregroundStyle(Color(.systemBackground))
                }
        case .pending:
            Circle()
                .strokeBorder(colour, lineWidth: 2)
                .frame(width: circle, height: circle)
        case .missed:
            Circle()
                .strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1)
                .frame(width: circle, height: circle)
        case .none:
            Circle()
                .fill(Color(.tertiarySystemFill))
                .frame(width: 8, height: 8)
                .frame(width: circle, height: circle)
        }
    }

    // MARK: Colours

    private func doneColour(_ row: HabitWeekRow) -> Color { row.tone?.ink ?? Theme.accent }
    private func tileFill(_ row: HabitWeekRow) -> Color { row.tone?.fill ?? Theme.brandFill }
    private func tileInk(_ row: HabitWeekRow) -> Color { row.tone?.ink ?? Theme.brandInk }
}

// MARK: - Section that owns the week offset

/// The habit week for Today: this week, with chevrons to look at earlier weeks.
struct HabitWeekSection: View {
    let input: StreakInput
    let today: Date

    @State private var offset = 0

    /// How far back the chevrons go.
    private static let maxOffset = 104

    var body: some View {
        let calendar = Calendar.current
        let anchor = calendar.date(byAdding: .day, value: -7 * offset, to: today) ?? today
        let states = ActivityCalendar.weekStates(input, weekOf: anchor, today: today, calendar: calendar)
        let start = states.days.first ?? anchor
        let names = states.days.map { $0.formatted(.dateTime.weekday(.wide)) }
        HabitWeekCard(
            rangeLabel: ActivityCalendar.weekRangeLabel(start: start, calendar: calendar),
            dayNames: names,
            todayIndex: states.todayIndex,
            rows: [
                HabitWeekRow(id: "study", title: "Study", icon: .bookOpen, tone: .sage, states: states.study),
                HabitWeekRow(id: "service", title: "Service", icon: .church, tone: .sky, states: states.service)
            ],
            canGoForward: offset > 0,
            canGoBack: offset < Self.maxOffset,
            onPrevious: { offset = min(offset + 1, Self.maxOffset) },
            onNext: { offset = max(offset - 1, 0) }
        )
    }
}

// MARK: - Preview

#Preview("Habit week") {
    let calendar = Calendar.current
    let today = Date()
    let studyDates = [0, 1, 2, 4, 5, 6, 8].compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    let input = StreakInput(
        studyDates: studyDates,
        serviceDates: [calendar.date(byAdding: .day, value: -3, to: today) ?? today],
        meetingWeekdays: [4, 7],
        readingSpans: [ReadingSpan(start: calendar.date(byAdding: .day, value: -30, to: today) ?? today, end: nil)]
    )
    ScrollView {
        HabitWeekSection(input: input, today: today)
            .padding(Theme.Spacing.m)
    }
    .background(Color(.systemBackground))
}

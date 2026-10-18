import SwiftUI

/// Month grid for a book's plan: studied, missed, still to come and today, each told apart by shape and icon
/// as well as colour. At accessibility text sizes the grid becomes a list of the month's plan days.
struct PlanCalendarView: View {
    let plan: PlanCalendar
    let tone: Tone
    /// Called with a day the reader may write a note for (today or earlier, inside the plan).
    let onSelect: (Date) -> Void

    @State private var month: Date
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var cellSize: CGFloat = 44

    init(plan: PlanCalendar, tone: Tone, onSelect: @escaping (Date) -> Void) {
        self.plan = plan
        self.tone = tone
        self.onSelect = onSelect
        _month = State(initialValue: plan.initialMonth)
    }

    /// The month on screen, falling back to the plan's own months if the plan was edited under us.
    private var shownMonth: Date {
        plan.months.contains(month) ? month : plan.initialMonth
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            monthHeader
            if typeSize.isAccessibilitySize {
                dayList
            } else {
                weekdayHeader
                grid
            }
            legend
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack(spacing: Theme.Spacing.xs) {
            monthButton(offset: -1, icon: .caretLeft, label: "Previous month")
            Text(shownMonth.formatted(.dateTime.month(.wide).year()))
                .font(.selahHeadline)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            monthButton(offset: 1, icon: .caretRight, label: "Next month")
        }
    }

    private func monthButton(offset: Int, icon: PIcon, label: String) -> some View {
        let target = plan.month(after: shownMonth, offset: offset)
        return Button {
            if let target { month = target }
        } label: {
            PIconView(icon, size: 18)
                .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .disabled(target == nil)
        .opacity(target == nil ? 0.3 : 1)
        .accessibilityLabel(label)
        .sensoryFeedback(.selection, trigger: month)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(plan.weekdaySymbols().enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: Grid

    private var grid: some View {
        let weeks = plan.weeks(in: shownMonth)
        return VStack(spacing: 2) {
            ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                HStack(spacing: 0) {
                    ForEach(Array(week.enumerated()), id: \.offset) { _, day in
                        if let day {
                            dayCell(day)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: cellSize)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ date: Date) -> some View {
        let state = plan.state(for: date)
        let isToday = plan.isToday(date)
        let number = plan.calendar.component(.day, from: date)

        if state == .outside {
            Text("\(number)")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: cellSize)
                .accessibilityHidden(true)
        } else {
            Button {
                onSelect(date)
            } label: {
                dayFace(number: number, state: state, isToday: isToday)
                    .frame(maxWidth: .infinity, minHeight: cellSize)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!plan.isOpen(date))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(spokenLabel(for: date, state: state, isToday: isToday))
            .accessibilityHint(plan.isOpen(date) ? "Opens the note for this day" : "Not open until this day")
            .accessibilityAddTraits(.isButton)
        }
    }

    private func dayFace(number: Int, state: PlanDayState, isToday: Bool) -> some View {
        let diameter = cellSize - 8
        return ZStack {
            switch state {
            case .studied:
                Circle().fill(tone.ink)
            case .missed:
                Circle().strokeBorder(Color(.secondaryLabel), lineWidth: 1)
            case .upcoming:
                Circle().strokeBorder(Color(.separator), lineWidth: 1)
            case .today, .outside:
                EmptyView()
            }
            if isToday {
                Circle()
                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                    .padding(-3)
            }
            faceContent(number: number, state: state, isToday: isToday)
        }
        .frame(width: diameter, height: diameter)
    }

    @ViewBuilder
    private func faceContent(number: Int, state: PlanDayState, isToday: Bool) -> some View {
        switch state {
        case .studied:
            VStack(spacing: 0) {
                PIconView(.check, size: 11, relativeTo: .caption2)
                    .fontWeight(.bold)
                Text("\(number)")
                    .font(.caption2.weight(isToday ? .heavy : .semibold))
            }
            .foregroundStyle(tone.fill)
        case .missed:
            VStack(spacing: 0) {
                PIconView(.x, size: 10, relativeTo: .caption2)
                Text("\(number)")
                    .font(.caption2.weight(isToday ? .heavy : .regular))
            }
            .foregroundStyle(Color(.secondaryLabel))
        case .upcoming:
            Text("\(number)")
                .font(.subheadline)
                .foregroundStyle(.primary)
        case .today:
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
        case .outside:
            EmptyView()
        }
    }

    // MARK: List (accessibility sizes)

    private var dayList: some View {
        VStack(spacing: 0) {
            ForEach(plan.planDays(in: shownMonth), id: \.self) { date in
                let state = plan.state(for: date)
                let isToday = plan.isToday(date)
                Button {
                    onSelect(date)
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        listGlyph(state)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                                .font(.body.weight(isToday ? .bold : .regular))
                            Text(isToday && state == .studied ? "Today, studied" : capitalizingFirst(state.spokenName))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!plan.isOpen(date))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spokenLabel(for: date, state: state, isToday: isToday))
                .accessibilityHint(plan.isOpen(date) ? "Opens the note for this day" : "Not open until this day")
                .accessibilityAddTraits(.isButton)
            }
        }
    }

    @ViewBuilder
    private func listGlyph(_ state: PlanDayState) -> some View {
        switch state {
        case .studied:
            PIconView(.checkCircle, filled: true, size: 24).foregroundStyle(tone.ink)
        case .missed:
            PIconView(.xCircle, size: 24).foregroundStyle(Color(.secondaryLabel))
        case .upcoming:
            PIconView(.calendarBlank, size: 24).foregroundStyle(Color(.tertiaryLabel))
        case .today:
            PIconView(.calendarCheck, size: 24).foregroundStyle(Color.accentColor)
        case .outside:
            EmptyView()
        }
    }

    // MARK: Legend

    private var legend: some View {
        FlowLayout(spacing: Theme.Spacing.m) {
            legendItem("Studied") {
                ZStack {
                    Circle().fill(tone.ink)
                    PIconView(.check, size: 10, relativeTo: .footnote)
                        .fontWeight(.bold)
                        .foregroundStyle(tone.fill)
                }
            }
            legendItem("Missed") {
                ZStack {
                    Circle().strokeBorder(Color(.secondaryLabel), lineWidth: 1)
                    PIconView(.x, size: 9, relativeTo: .footnote)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
            legendItem("Still to come") {
                Circle().strokeBorder(Color(.separator), lineWidth: 1)
            }
            legendItem("Today") {
                Circle().strokeBorder(Color.accentColor, lineWidth: 2.5)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Key: studied, missed, still to come, today")
    }

    private func legendItem<Glyph: View>(_ title: String, @ViewBuilder glyph: () -> Glyph) -> some View {
        HStack(spacing: Theme.Spacing.xxs) {
            glyph()
                .frame(width: 18, height: 18)
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Words

    private func spokenLabel(for date: Date, state: PlanDayState, isToday: Bool) -> String {
        let day = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        switch (state, isToday) {
        case (.studied, true): return "\(day), today, studied"
        case (.today, _): return "\(day), today, no note yet"
        default: return "\(day), \(state.spokenName)"
        }
    }
}

/// "studied" becomes "Studied". Only the first letter changes.
private func capitalizingFirst(_ text: String) -> String {
    text.prefix(1).uppercased() + text.dropFirst()
}

#Preview {
    let today = Date()
    let start = Calendar.current.date(byAdding: .day, value: -6, to: today) ?? today
    let entries = [1, 2, 4].compactMap { Calendar.current.date(byAdding: .day, value: -$0, to: today) }
    return ScrollView {
        SurfaceCard {
            PlanCalendarView(
                plan: PlanCalendar(start: start, plannedDays: 20, entryDates: entries, today: today),
                tone: .sky
            ) { _ in }
        }
        .padding(Theme.Spacing.m)
    }
}

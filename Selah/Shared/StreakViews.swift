import SwiftUI
import UIKit

// Streak visuals for Today: the streak hero card (glowing flame, big number, week row) and the celebration when
// the streak goes up.

enum StreakKind: String, CaseIterable, Hashable, Sendable {
    case study, service

    /// `@AppStorage` key for the streak shown on Today.
    static let storageKey = "todayStreakKind"

    var title: String {
        switch self {
        case .study: return "Study"
        case .service: return "Service"
        }
    }

    func count(in summary: StreakSummary) -> StreakCount {
        switch self {
        case .study: return summary.study
        case .service: return summary.service
        }
    }
}

// MARK: - Palette

/// Hot pink to coral on a deep warm-neutral card. Never purple or yellow.
/// Contrast on the card (#1A1416, luminance about 0.009): pink #FF4F81 about 5.7:1, coral #FF8A80 about 7.5:1,
/// label pink #FF7A94 about 6.5:1, white at 60% about 6:1. Dark ink #1A1416 on pink #FF4F81 about 5.7:1.
enum StreakPalette {
    static let pink = Color(red: 1.0, green: 0.31, blue: 0.51)           // #FF4F81
    static let coral = Color(red: 1.0, green: 0.54, blue: 0.50)          // #FF8A80
    static let label = Color(red: 1.0, green: 0.48, blue: 0.58)          // #FF7A94
    static let check = Color(red: 1.0, green: 0.56, blue: 0.66)          // #FF8FA8
    static let cardTop = Color(red: 0.102, green: 0.078, blue: 0.086)    // #1A1416
    static let cardBottom = Color(red: 0.078, green: 0.063, blue: 0.071) // #141012
    static let ink = Color(red: 0.102, green: 0.078, blue: 0.086)        // #1A1416
}

/// Card colours per appearance: a soft pink card in light mode, the deep warm-neutral card in dark mode.
/// Light contrast on #FFEBEF (luminance about 0.87): label #C42A5C about 4.8:1, number pink #E0336B about 3.6:1
/// (large text), black at 60% about 6:1. `faint` is black or white, used at low opacity for day cells and lines.
struct StreakColours {
    let cardTop: Color
    let cardBottom: Color
    let label: Color
    let numberTop: Color
    let numberBottom: Color
    let check: Color
    let faint: Color
    let weekPanel: Color
    let glow: Double

    static func forScheme(_ scheme: ColorScheme) -> StreakColours {
        if scheme == .dark {
            return StreakColours(
                cardTop: StreakPalette.cardTop,
                cardBottom: StreakPalette.cardBottom,
                label: StreakPalette.label,
                numberTop: StreakPalette.coral,
                numberBottom: StreakPalette.pink,
                check: StreakPalette.check,
                faint: .white,
                weekPanel: Color.white.opacity(0.06),
                glow: 0.5
            )
        }
        return StreakColours(
            cardTop: Color(red: 1.0, green: 0.945, blue: 0.953),     // #FFF1F3
            cardBottom: Color(red: 1.0, green: 0.922, blue: 0.937),  // #FFEBEF
            label: Color(red: 0.769, green: 0.165, blue: 0.361),     // #C42A5C
            numberTop: Color(red: 0.941, green: 0.337, blue: 0.431), // #F0566E
            numberBottom: Color(red: 0.878, green: 0.2, blue: 0.42), // #E0336B
            check: Color(red: 0.878, green: 0.2, blue: 0.42),        // #E0336B
            faint: .black,
            weekPanel: Color.white.opacity(0.75),
            glow: 0.32
        )
    }
}

// MARK: - Hero

/// One day of the week row.
struct StreakWeekCell: Equatable, Sendable {
    var date: Date
    var isToday: Bool
    var state: WeekDayState
}

/// The streak as a feature card: a glowing hot pink flame with floating embers, the big number, "days streak" and
/// the best run, then the week M to S. A soft pink card in light mode, a deep warm-neutral card in dark mode.
/// Change `celebration` to play the celebration (flare, bounce, particles, haptic).
struct StreakHero: View {
    let kind: StreakKind
    let count: Int
    let best: Int
    let done: Bool
    let days: [StreakWeekCell]
    /// Bump this number to play the celebration.
    var celebration: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 64
    @ScaledMetric(relativeTo: .title3) private var labelSize: CGFloat = 20
    @State private var bounced = false
    @State private var burstProgress: CGFloat = 0
    @State private var showBurst = false
    @State private var flared = false

    private var colours: StreakColours { .forScheme(colorScheme) }

    private var spokenDays: String { count == 1 ? "1 day" : "\(count) days" }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            VStack(spacing: Theme.Spacing.xxs) {
                flameStack
                numberText
                Text("\(count == 1 ? "day" : "days") streak \u{00B7} \(kind.title)")
                    .font(.custom(SelahFontFamily.body, size: labelSize, relativeTo: .title3).weight(.semibold))
                    .foregroundStyle(colours.label)
                Text("Best \(best)")
                    .font(.selahLabel)
                    .foregroundStyle(colours.faint.opacity(colorScheme == .dark ? 0.65 : 0.6))
            }
            .accessibilityHidden(true)

            StreakWeekRow(days: days)
                .padding(.vertical, Theme.Spacing.s)
                .padding(.horizontal, Theme.Spacing.xs)
                .background(colours.weekPanel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.top, Theme.Spacing.m)
        .padding([.horizontal, .bottom], Theme.Spacing.s)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [colours.cardTop, colours.cardBottom],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(colours.faint.opacity(0.06), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) streak, \(spokenDays), best \(best)")
        .accessibilityValue("\(done ? "Done today. " : "")This week: \(StreakWeekRow.summary(days))")
        .onChange(of: celebration) { _, _ in play() }
        .sensoryFeedback(.success, trigger: celebration)
    }

    /// A streak of 0 shows the grey flame with no glow or embers.
    private var lit: Bool { count > 0 }

    private var flameStack: some View {
        ZStack {
            if lit {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [StreakPalette.pink.opacity(flared ? colours.glow + 0.15 : colours.glow), StreakPalette.pink.opacity(0)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 100
                        )
                    )
                    .frame(width: 210, height: 210)
                    .blur(radius: 14)
                    .offset(y: 8)
                StreakEmbers()
                    .frame(width: 180, height: 170)
            }
            flame
        }
        .frame(height: 160)
    }

    /// The delivered flame artwork when the asset catalog has it, otherwise the drawn flame.
    @ViewBuilder
    private var flame: some View {
        if let art = UIImage(named: lit ? "StreakFlame" : "StreakFlameOff") {
            Image(uiImage: art)
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .scaleEffect(flared ? 1.08 : 1)
                .animation(.spring(duration: 0.4, bounce: 0.4), value: flared)
        } else {
            StreakFlame(palette: .hero, flared: flared)
                .frame(height: 112)
                .shadow(color: StreakPalette.pink.opacity(colorScheme == .dark ? 0.55 : 0.35), radius: 16)
        }
    }

    private var numberText: some View {
        Text("\(count)")
            .font(.custom(SelahFontFamily.display, size: numberSize, relativeTo: .largeTitle).weight(.heavy))
            .monospacedDigit()
            .foregroundStyle(
                LinearGradient(colors: [colours.numberTop, colours.numberBottom], startPoint: .top, endPoint: .bottom)
            )
            .scaleEffect(bounced ? 1.2 : 1)
            .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
            .animation(.easeInOut(duration: 0.3), value: count)
            .background {
                if showBurst {
                    ParticleBurst(progress: burstProgress, colour: StreakPalette.coral)
                }
            }
    }

    private func play() {
        // Reduce Motion: the number cross-fades (above) and nothing else moves.
        guard !reduceMotion else { return }
        burstProgress = 0
        showBurst = true
        withAnimation(.spring(duration: 0.35, bounce: 0.6)) { bounced = true }
        flared = true
        withAnimation(.easeOut(duration: 0.7)) { burstProgress = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { bounced = false }
            try? await Task.sleep(for: .milliseconds(600))
            flared = false
            showBurst = false
        }
    }
}

/// A few small pink and coral embers that drift up and fade around the flame. Nothing is drawn with Reduce Motion.
private struct StreakEmbers: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = true

    private var paused: Bool { reduceMotion || !visible || scenePhase != .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            let time: Double = timeline.date.timeIntervalSinceReferenceDate
            let still = reduceMotion
            Canvas { context, size in
                guard !still else { return }
                for index in 0..<5 {
                    let seed = Double(index)
                    let speed = 0.16 + 0.03 * seed
                    let raw = time * speed + seed * 0.37
                    let progress = CGFloat(raw - raw.rounded(.down))
                    let side: CGFloat = index % 2 == 0 ? -1 : 1
                    let spread: CGFloat = 18 + CGFloat(seed) * 11
                    let wobble: CGFloat = CGFloat(sin(time * 1.3 + seed * 1.9)) * 8
                    let x: CGFloat = size.width / 2 + side * spread + wobble
                    let y: CGFloat = size.height * 0.62 - progress * size.height * 0.62
                    let radius: CGFloat = (2.2 + CGFloat(index % 3)) * (1 - progress * 0.4)
                    let rect = CGRect(x: x - radius * 0.6, y: y - radius, width: radius * 1.2, height: radius * 2)
                    let colour: Color = index % 2 == 0 ? StreakPalette.pink : StreakPalette.coral
                    let alpha: Double = Double(1 - progress) * 0.85
                    context.fill(Path(ellipseIn: rect), with: .color(colour.opacity(alpha)))
                }
            }
        }
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Small circles that fly out from the number and fade.
private struct ParticleBurst: View {
    let progress: CGFloat
    let colour: Color

    private let count = 12

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                particle(index)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    // Split out so the type checker doesn't time out on one long expression.
    private func particle(_ index: Int) -> some View {
        let angle: Double = Double(index) / Double(count) * 2.0 * Double.pi
        let distance: CGFloat = 60.0 * progress
        let dx: CGFloat = CGFloat(cos(angle)) * distance
        let dy: CGFloat = CGFloat(sin(angle)) * distance
        let scale: CGFloat = 1.0 - progress * 0.5
        let strength: Double = index % 2 == 0 ? 0.9 : 0.55
        let alpha: Double = Double(1.0 - progress) * strength
        return Circle()
            .fill(colour)
            .frame(width: 6, height: 6)
            .offset(x: dx, y: dy)
            .scaleEffect(scale)
            .opacity(alpha)
    }
}

// MARK: - Week row

/// M T W T F S S. Done days are check marks, joined by a translucent pink capsule across consecutive runs; today
/// is a bright pink circle with a check (a pink ring while not done yet); the other days are plain day numbers.
struct StreakWeekRow: View {
    let days: [StreakWeekCell]

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var circle: CGFloat = 32

    private var colours: StreakColours { .forScheme(colorScheme) }

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    Text(Self.letters[index % Self.letters.count])
                        .font(.selahLabel)
                        .fontWeight(day.isToday ? .bold : .regular)
                        .foregroundStyle(colours.faint.opacity(day.isToday ? 1 : 0.6))
                        .frame(maxWidth: .infinity)
                }
            }
            HStack(spacing: 0) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    cell(day)
                        .frame(maxWidth: .infinity, minHeight: circle + 6)
                }
            }
            .background { capsules }
        }
    }

    /// Runs of consecutive done days, as (first index, length).
    private var runs: [Run] {
        var result: [Run] = []
        var start: Int?
        for (index, day) in days.enumerated() {
            if day.state == .done {
                if start == nil { start = index }
            } else if let begin = start {
                result.append(Run(start: begin, length: index - begin))
                start = nil
            }
        }
        if let begin = start { result.append(Run(start: begin, length: days.count - begin)) }
        return result
    }

    private struct Run {
        let start: Int
        let length: Int
    }

    private var capsules: some View {
        GeometryReader { geo in
            let slot: CGFloat = geo.size.width / CGFloat(max(days.count, 1))
            ForEach(Array(runs.enumerated()), id: \.offset) { _, run in
                let width: CGFloat = CGFloat(run.length - 1) * slot + circle + 8
                let centre: CGFloat = (CGFloat(run.start) + CGFloat(run.length) / 2) * slot
                Capsule()
                    .fill(StreakPalette.pink.opacity(colorScheme == .dark ? 0.28 : 0.18))
                    .frame(width: width, height: circle + 6)
                    .position(x: centre, y: geo.size.height / 2)
            }
        }
    }

    private func dayNumber(_ day: StreakWeekCell) -> some View {
        let number = Calendar.current.component(.day, from: day.date)
        return Text("\(number)")
            .font(.custom(SelahFontFamily.display, size: 15, relativeTo: .subheadline).weight(.medium))
            .monospacedDigit()
    }

    @ViewBuilder
    private func cell(_ day: StreakWeekCell) -> some View {
        switch day.state {
        case .done:
            if day.isToday {
                Circle()
                    .fill(StreakPalette.pink)
                    .frame(width: circle, height: circle)
                    .overlay {
                        PIconView(.check, size: 16, relativeTo: .body)
                            .foregroundStyle(StreakPalette.ink)
                    }
            } else {
                PIconView(.check, size: 16, relativeTo: .body)
                    .foregroundStyle(colours.check)
                    .frame(width: circle, height: circle)
            }
        case .pending:
            Circle()
                .strokeBorder(StreakPalette.pink, lineWidth: 2)
                .frame(width: circle, height: circle)
                .overlay { dayNumber(day).foregroundStyle(colours.check) }
        case .missed:
            dayNumber(day)
                .foregroundStyle(colours.faint.opacity(0.55))
                .frame(width: circle, height: circle)
        case .none:
            Circle()
                .fill(colours.faint.opacity(day.isToday ? 0.12 : 0.06))
                .frame(width: circle, height: circle)
                .overlay { dayNumber(day).foregroundStyle(colours.faint.opacity(0.75)) }
        }
    }

    static func summary(_ days: [StreakWeekCell]) -> String {
        days.map { day in
            let name = day.date.formatted(.dateTime.weekday(.wide))
            switch day.state {
            case .done: return "\(name) done"
            case .pending: return "\(name) today, not done yet"
            case .missed: return "\(name) missed"
            case .none: return "\(name) nothing due"
            }
        }
        .joined(separator: ", ")
    }
}

// MARK: - Section with celebration

/// The streak hero on Today: only the kind the user chose in Settings.
///
/// Celebration: when today becomes done for the streak and that date was not celebrated yet (stored per kind in
/// `@AppStorage`), the hero first shows yesterday's count, then rolls up to today's with the bounce and burst.
/// It only plays while `isActive` is true (Today is on screen with nothing on top of it).
///
/// `input` is the same `StreakInput` the `summary` was built from; the week row reads its days from it.
struct StreakSection: View {
    let kind: StreakKind
    let summary: StreakSummary
    let input: StreakInput
    let today: Date
    var isActive: Bool = true

    @AppStorage("streak.celebrated.study") private var celebratedStudy = ""
    @AppStorage("streak.celebrated.service") private var celebratedService = ""

    @State private var shown: Int?
    @State private var tick = 0
    @State private var celebrating = false

    private var dayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: today)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private var lastCelebrated: String {
        kind == .study ? celebratedStudy : celebratedService
    }

    private func markCelebrated() {
        if kind == .study { celebratedStudy = dayKey } else { celebratedService = dayKey }
    }

    private var count: StreakCount { kind.count(in: summary) }
    private var isPending: Bool { count.doneToday && lastCelebrated != dayKey }
    private var displayed: Int {
        if let shown { return shown }
        return isPending ? max(count.current - 1, 0) : count.current
    }

    private var weekCells: [StreakWeekCell] {
        let week = ActivityCalendar.weekStates(input, weekOf: today, today: today, calendar: Calendar.current)
        let states = kind == .study ? week.study : week.service
        return week.days.enumerated().map { index, date in
            StreakWeekCell(
                date: date,
                isToday: week.todayIndex == index,
                state: states.indices.contains(index) ? states[index] : .none
            )
        }
    }

    var body: some View {
        StreakHero(
            kind: kind,
            count: displayed,
            best: max(count.best, count.current),
            done: count.doneToday,
            days: weekCells,
            celebration: tick
        )
        .onAppear { sync() }
        .onChange(of: summary) { _, _ in sync() }
        .onChange(of: isActive) { _, _ in sync() }
        .onChange(of: kind) { _, _ in
            shown = nil
            celebrating = false
            sync()
        }
    }

    /// Brings the shown count in line with the data, and plays the celebration if it is due.
    private func sync() {
        if isPending {
            guard isActive else {
                // Not on screen: hold yesterday's count until the user sees it.
                shown = max(count.current - 1, 0)
                return
            }
            guard !celebrating else { return }
            celebrating = true
            shown = max(count.current - 1, 0)
            markCelebrated()
            let target = count.current
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                shown = target
                tick += 1
                celebrating = false
            }
        } else if !celebrating {
            shown = count.current
        }
    }
}

private struct StreakPreview: View {
    let kind: StreakKind

    var body: some View {
        let today = Date()
        let calendar = Calendar.current
        let studyDates = (0..<4).compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
        let input = StreakInput(
            studyDates: studyDates,
            serviceDates: [today],
            meetingWeekdays: [calendar.component(.weekday, from: today)],
            readingSpans: [ReadingSpan(start: studyDates.last ?? today, end: nil)]
        )
        ScrollView {
            StreakSection(
                kind: kind,
                summary: Streaks.summary(input, today: today),
                input: input,
                today: today
            )
            .padding(Theme.Spacing.m)
        }
    }
}

#Preview("Streak, study") {
    StreakPreview(kind: .study)
}

#Preview("Streak, service") {
    StreakPreview(kind: .service)
}

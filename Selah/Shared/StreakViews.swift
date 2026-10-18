import SwiftUI

// Streak visuals for Today: three pills, a week strip, and the celebration when a streak goes up.

enum StreakKind: CaseIterable, Hashable, Sendable {
    case study, service, overall

    var title: String {
        switch self {
        case .study: return "Study"
        case .service: return "Service"
        case .overall: return "Overall"
        }
    }

    func count(in summary: StreakSummary) -> StreakCount {
        switch self {
        case .study: return summary.study
        case .service: return summary.service
        case .overall: return summary.overall
        }
    }
}

// MARK: - Pill

/// One streak: a flame and the number of days. Coral when a streak is running, quiet slate at zero.
/// The flame is filled once today is done. Change `celebration` to play the celebration.
struct StreakPill: View {
    let kind: StreakKind
    let count: Int
    let done: Bool
    /// Bump this number to play the celebration (bounce, particles, haptic).
    var celebration: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounced = false
    @State private var burstProgress: CGFloat = 0
    @State private var showBurst = false

    private var tone: Tone { count > 0 ? .coral : .slate }

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.xxs) {
                PIconView(.flame, filled: done, size: 24, relativeTo: .title3)
                    .foregroundStyle(tone.ink)
                    .scaleEffect(bounced ? 1.4 : 1)
                    .background {
                        if showBurst {
                            ParticleBurst(progress: burstProgress)
                        }
                    }
                Text("\(count)")
                    .font(.selahStat)
                    .foregroundStyle(tone.ink)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                    .animation(.easeInOut(duration: 0.3), value: count)
            }
            Text(kind.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tone.inkSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, Theme.Spacing.s)
        .padding(.horizontal, Theme.Spacing.xs)
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) streak")
        .accessibilityValue(accessibilityValue)
        .onChange(of: celebration) { _, _ in play() }
        .sensoryFeedback(.success, trigger: celebration)
    }

    private var accessibilityValue: String {
        let days = count == 1 ? "1 day" : "\(count) days"
        return done ? "\(days), done today" : days
    }

    private func play() {
        // Reduce Motion: the number cross-fades (above) and nothing else moves.
        guard !reduceMotion else { return }
        burstProgress = 0
        showBurst = true
        withAnimation(.spring(duration: 0.35, bounce: 0.6)) { bounced = true }
        withAnimation(.easeOut(duration: 0.7)) { burstProgress = 1 }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            withAnimation(.spring(duration: 0.4, bounce: 0.4)) { bounced = false }
            try? await Task.sleep(for: .milliseconds(600))
            showBurst = false
        }
    }
}

/// Small circles that fly out from the centre and fade. Coral, teal and sky.
private struct ParticleBurst: View {
    let progress: CGFloat

    private let colours: [Color] = [Tone.coral.ink, Theme.brandInk, Tone.sky.ink]
    private let count = 10

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
        let distance: CGFloat = 32.0 * progress
        let dx: CGFloat = CGFloat(cos(angle)) * distance
        let dy: CGFloat = CGFloat(sin(angle)) * distance
        let scale: CGFloat = 1.0 - progress * 0.5
        let alpha: Double = Double(1.0 - progress) * 0.85
        let colour: Color = colours[index % colours.count]
        return Circle()
            .fill(colour)
            .frame(width: 5, height: 5)
            .offset(x: dx, y: dy)
            .scaleEffect(scale)
            .opacity(alpha)
    }
}

// MARK: - Week strip

/// M T W T F S S: a filled dot when the day's work is done, a ring around today, dim when nothing was due.
struct WeekStrip: View {
    let days: [WeekDay]

    private static let letters = ["M", "T", "W", "T", "F", "S", "S"]
    @ScaledMetric(relativeTo: .body) private var dot: CGFloat = 24

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                VStack(spacing: Theme.Spacing.xs) {
                    Text(Self.letters[index % Self.letters.count])
                        .font(.footnote.weight(day.isToday ? .bold : .regular))
                        .foregroundStyle(day.isToday ? Color.primary : Color.secondary)
                    dotView(for: day)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week")
        .accessibilityValue(summary)
    }

    @ViewBuilder
    private func dotView(for day: WeekDay) -> some View {
        ZStack {
            switch day.state {
            case .done:
                Circle().fill(Theme.brandInk)
                PIconView(.check, size: 12, relativeTo: .caption)
                    .foregroundStyle(Color(.systemBackground))
            case .pending:
                Circle().fill(Tone.coral.fill)
            case .missed:
                Circle().strokeBorder(Tone.slate.ink.opacity(0.35), lineWidth: 1.5)
                    .padding(3)
            case .none:
                Circle().fill(Tone.slate.fill)
                    .padding(3)
            }
            if day.isToday {
                Circle().strokeBorder(Tone.coral.ink, lineWidth: 2)
            }
        }
        .frame(width: dot, height: dot)
    }

    private var summary: String {
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

/// The streak row on Today: three pills and the week strip.
///
/// Celebration: when today becomes done for a streak and that date was not celebrated yet (stored per kind in
/// `@AppStorage`), the pill first shows yesterday's count, then rolls up to today's with the bounce and burst.
/// It only plays while `isActive` is true (Today is on screen with nothing on top of it), so it is never wasted
/// behind a full-screen editor.
struct StreakSection: View {
    let summary: StreakSummary
    let week: [WeekDay]
    let today: Date
    var isActive: Bool = true
    /// Today shows the habit week card instead, so it turns the strip off.
    var showsWeekStrip: Bool = true

    @AppStorage("streak.celebrated.study") private var celebratedStudy = ""
    @AppStorage("streak.celebrated.service") private var celebratedService = ""
    @AppStorage("streak.celebrated.overall") private var celebratedOverall = ""

    @State private var shown: [StreakKind: Int] = [:]
    @State private var ticks: [StreakKind: Int] = [:]
    @State private var celebrating: Set<StreakKind> = []

    @Environment(\.dynamicTypeSize) private var typeSize

    private var dayKey: String {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: today)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private func lastCelebrated(_ kind: StreakKind) -> String {
        switch kind {
        case .study: return celebratedStudy
        case .service: return celebratedService
        case .overall: return celebratedOverall
        }
    }

    private func markCelebrated(_ kind: StreakKind) {
        switch kind {
        case .study: celebratedStudy = dayKey
        case .service: celebratedService = dayKey
        case .overall: celebratedOverall = dayKey
        }
    }

    private func isPending(_ kind: StreakKind) -> Bool {
        kind.count(in: summary).doneToday && lastCelebrated(kind) != dayKey
    }

    private func displayed(_ kind: StreakKind) -> Int {
        let count = kind.count(in: summary)
        if let value = shown[kind] { return value }
        return isPending(kind) ? max(count.current - 1, 0) : count.current
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(spacing: Theme.Spacing.xs))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.xs))
            layout {
                ForEach(StreakKind.allCases, id: \.self) { kind in
                    StreakPill(
                        kind: kind,
                        count: displayed(kind),
                        done: kind.count(in: summary).doneToday,
                        celebration: ticks[kind] ?? 0
                    )
                }
            }
            if showsWeekStrip {
                SurfaceCard {
                    WeekStrip(days: week)
                }
            }
        }
        .onAppear { sync() }
        .onChange(of: summary) { _, _ in sync() }
        .onChange(of: isActive) { _, _ in sync() }
    }

    /// Brings the shown counts in line with the data, and plays any celebration that is due.
    private func sync() {
        for kind in StreakKind.allCases {
            let count = kind.count(in: summary)
            if isPending(kind) {
                guard isActive else {
                    // Not on screen: hold yesterday's count until the user sees it.
                    shown[kind] = max(count.current - 1, 0)
                    continue
                }
                guard !celebrating.contains(kind) else { continue }
                celebrating.insert(kind)
                shown[kind] = max(count.current - 1, 0)
                markCelebrated(kind)
                let target = count.current
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    shown[kind] = target
                    ticks[kind, default: 0] += 1
                    celebrating.remove(kind)
                }
            } else if !celebrating.contains(kind) {
                shown[kind] = count.current
            }
        }
    }
}

#Preview("Streaks") {
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
            summary: Streaks.summary(input, today: today),
            week: Streaks.week(input, today: today),
            today: today
        )
        .padding(Theme.Spacing.m)
    }
}

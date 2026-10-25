import SwiftUI

// Streak visuals for Today: one coloured streak tile and the celebration when the streak goes up.

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

    /// Solid tile colour. Study uses the accent; Service uses sage ink (deep green in light mode, pale sage in
    /// dark mode).
    var tileFill: Color {
        switch self {
        case .study: return Theme.accent
        case .service: return Tone.sage.ink
        }
    }

    /// Label colour on `tileFill`: the opposite of the system background, so it flips with the mode.
    /// Study: white on the accent in light, black on the lighter accent in dark. Service: white on deep sage in
    /// light (about 8:1), black on pale sage in dark (about 13:1).
    var tileLabel: Color { Color(.systemBackground) }
}

// MARK: - Tile

/// One streak as a solid coloured tile: a burning flame on a dark badge, the big number, "day streak, Study",
/// and the best run.
/// Change `celebration` to play the celebration (bounce, particles, haptic).
struct StreakTile: View {
    let kind: StreakKind
    let count: Int
    let best: Int
    let done: Bool
    /// Bump this number to play the celebration.
    var celebration: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounced = false
    @State private var burstProgress: CGFloat = 0
    @State private var showBurst = false
    @State private var flared = false

    private var spokenDays: String { count == 1 ? "1 day" : "\(count) days" }

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            StreakFlameBadge(flared: flared)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(count)")
                    .font(.selahStatLarge)
                    .foregroundStyle(kind.tileLabel)
                    .scaleEffect(bounced ? 1.25 : 1, anchor: .leading)
                    .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(count)))
                    .animation(.easeInOut(duration: 0.3), value: count)
                    .background(alignment: .leading) {
                        if showBurst {
                            ParticleBurst(progress: burstProgress, colour: kind.tileLabel)
                        }
                    }
                Text("day streak \u{00B7} \(kind.title)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(kind.tileLabel)
                Text("Best \(best)")
                    .font(.footnote)
                    .foregroundStyle(kind.tileLabel.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.m)
        .background(kind.tileFill, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.title) streak, \(spokenDays), best \(best)")
        .accessibilityValue(done ? "Done today" : "")
        .onChange(of: celebration) { _, _ in play() }
        .sensoryFeedback(.success, trigger: celebration)
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

/// Small circles that fly out from the number and fade, in the tile's label colour.
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
        let distance: CGFloat = 40.0 * progress
        let dx: CGFloat = CGFloat(cos(angle)) * distance
        let dy: CGFloat = CGFloat(sin(angle)) * distance
        let scale: CGFloat = 1.0 - progress * 0.5
        let strength: Double = index % 2 == 0 ? 0.9 : 0.55
        let alpha: Double = Double(1.0 - progress) * strength
        return Circle()
            .fill(colour)
            .frame(width: 6, height: 6)
            .offset(x: dx + 24, y: dy)
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

/// The streak tile on Today: only the kind the user chose in Settings.
///
/// Celebration: when today becomes done for the streak and that date was not celebrated yet (stored per kind in
/// `@AppStorage`), the tile first shows yesterday's count, then rolls up to today's with the bounce and burst.
/// It only plays while `isActive` is true (Today is on screen with nothing on top of it).
struct StreakSection: View {
    let kind: StreakKind
    let summary: StreakSummary
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

    var body: some View {
        StreakTile(
            kind: kind,
            count: displayed,
            best: max(count.best, count.current),
            done: count.doneToday,
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
            StreakSection(kind: kind, summary: Streaks.summary(input, today: today), today: today)
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

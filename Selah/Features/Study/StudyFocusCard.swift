import SwiftUI
import SwiftData

/// The book you are reading, at a glance (owner's reference, 27 Oct): a soft tinted frame with overall progress on
/// top, a white card with the book, the study title, a short description, the coral today's note button and the day
/// count with the reminder bell, then whether today's note is saved. Used on Today and at the top of the book page.
struct StudyFocusCard: View {
    let plan: ReadingPlan
    /// True when today's note exists (the button then opens it).
    let hasEntryToday: Bool
    /// Opens today's note (new or existing). Not called for a book that hasn't started: the button starts it.
    let onToday: () -> Void

    private var progress: Double {
        guard plan.totalChapters > 0 else { return 0 }
        return min(max(Double(plan.chaptersRead.count) / Double(plan.totalChapters), 0), 1)
    }

    private var percentText: String { "\(Int((progress * 100).rounded()))%" }

    var body: some View {
        VStack(spacing: 0) {
            progressStrip
            mainCard
                .padding(.horizontal, 6)
            todayStrip
        }
        .background(
            LinearGradient(
                colors: [Theme.brandFill, Theme.brandFill.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
    }

    // MARK: Top strip

    private var progressStrip: some View {
        HStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle()
                    .stroke(Theme.brandInk.opacity(0.2), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Theme.brandInk, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)
            Text("Overall progress")
                .font(.selahLabelSmall)
            Spacer(minLength: Theme.Spacing.s)
            Text(percentText)
                .font(.selahLabelSmall.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(Theme.brandInk)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overall progress")
        .accessibilityValue("\(percentText). \(StudyActions.progressText(for: plan))")
    }

    // MARK: Card

    private var hasTitle: Bool { !plan.title.trimmingCharacters(in: .whitespaces).isEmpty }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(hasTitle ? plan.bookName : "Bible study")
                .font(.selahLabel)
                .foregroundStyle(.secondary)
            Text(plan.displayTitle)
                .font(.custom(SelahFontFamily.display, size: 24, relativeTo: .title2).weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
                .accessibilityAddTraits(.isHeader)
            let summary = plan.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                Text(summary)
                    .font(.selahLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Spacing.s) {
                    todayButton
                    Spacer(minLength: Theme.Spacing.xs)
                    dayInfo
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    todayButton
                    dayInfo
                }
            }
            .padding(.top, Theme.Spacing.m)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .selahCard(radius: 22)
    }

    /// The coral button, text only: start the book, write today's note, or open it.
    private var todayButton: some View {
        Button {
            if plan.startDate == nil {
                StudyActions.startReading(plan)
            } else {
                onToday()
            }
        } label: {
            Text(buttonTitle)
                .font(.selahButton)
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, 20)
                .frame(minHeight: Theme.minTapTarget)
                .background(Theme.accent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-note-button")
    }

    private var buttonTitle: String {
        if plan.startDate == nil { return "Start reading" }
        return hasEntryToday ? "Open today's note" : "Write today's note"
    }

    private var hasReminders: Bool { !plan.reminders.isEmpty }

    private var dayText: String {
        switch plan.status {
        case .reading:
            let pace = plan.pace()
            return "Day \(pace.dayNumber)/\(pace.plannedDays)"
        case .upNext:
            return "\(plan.plannedDays) days"
        case .done:
            return "Done"
        }
    }

    /// The day count with the reminder bell (on or off). Times are set in Edit plan.
    private var dayInfo: some View {
        HStack(spacing: 6) {
            PIconView(hasReminders ? .bell : .bellSlash, size: 15, relativeTo: .footnote)
            Text(dayText)
                .font(.selahLabelSmall)
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayText.replacingOccurrences(of: "/", with: " of ")), reminders \(hasReminders ? "on" : "off")")
    }

    // MARK: Bottom strip

    private var status: (icon: PIcon, text: String) {
        switch plan.status {
        case .upNext:
            return (.bookmarkSimple, "Not started yet")
        case .done:
            return (.checkCircle, StudyActions.planLine(for: plan))
        case .reading:
            return hasEntryToday
                ? (.checkCircle, "Today's note is saved")
                : (.clock, "Today's note isn't written yet")
        }
    }

    private var todayStrip: some View {
        let status = status
        return HStack(spacing: Theme.Spacing.s) {
            PIconView(status.icon, size: 15, relativeTo: .footnote)
            Text(status.text)
                .font(.selahLabelSmall)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.brandInk)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

private struct StudyFocusCardPreview: View {
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            StudyFocusCard(plan: plan, hasEntryToday: true) {}
                .padding(Theme.Spacing.m)
        }
    }
}

#Preview {
    StudyFocusCardPreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

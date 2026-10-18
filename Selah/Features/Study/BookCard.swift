import SwiftUI
import SwiftData

/// A pill that sits on a tone card: the card's ink on a lighter wash, so it reads on the tinted fill
/// (a plain `Pill` would be the same colour as the card).
struct CardPill: View {
    let text: String
    var icon: PIcon? = nil
    let tone: Tone

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                PIconView(icon, size: 14, relativeTo: .footnote)
            }
            Text(text)
                .font(.selahLabelSmall.weight(.semibold))
        }
        .foregroundStyle(tone.ink)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// One book in the Study list: a card tinted with the book's colour, an optional banner strip on top,
/// the serif book name, a progress ring and pills.
struct BookCard: View {
    let plan: ReadingPlan

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 64

    private var tone: Tone { plan.cardTone }

    private var progress: Double {
        guard plan.totalChapters > 0 else { return 0 }
        return Double(plan.chaptersRead.count) / Double(plan.totalChapters)
    }

    private var summary: String {
        var parts = [plan.bookName, StudyActions.progressText(for: plan), StudyActions.planLine(for: plan)]
        if let reminders = StudyActions.remindersText(for: plan) { parts.append(reminders) }
        return parts.joined(separator: ". ")
    }

    var body: some View {
        VStack(spacing: 0) {
            if let data = plan.bannerData {
                BannerImageView(data: data, height: 88)
            }
            content
                .padding(Theme.Spacing.m)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.fill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityHint("Opens the book page")
        .accessibilityIdentifier("book-card")
    }

    private var content: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
            : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
        return layout {
            ring

            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(plan.bookName)
                    .font(.selahCardTitle)
                    .foregroundStyle(tone.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                FlowLayout(spacing: Theme.Spacing.xs) {
                    ForEach(pills, id: \.text) { pill in
                        CardPill(text: pill.text, icon: pill.icon, tone: tone)
                    }
                }
            }

            if !typeSize.isAccessibilitySize {
                PIconView(.caretRight, size: 14, relativeTo: .footnote)
                    .font(.selahLabelSmall.weight(.semibold))
                    .foregroundStyle(tone.inkSecondary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var ring: some View {
        ZStack {
            Circle().fill(Color(.systemBackground).opacity(0.6))
            ProgressRing(
                progress: progress,
                lineWidth: 6,
                tone: tone,
                centreLabel: "\(plan.chaptersRead.count)/\(plan.totalChapters)",
                accessibilityLabel: "Chapters read",
                accessibilityValue: StudyActions.progressText(for: plan)
            )
            .foregroundStyle(tone.ink)
            .padding(5)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private struct PillItem {
        let text: String
        let icon: PIcon?
    }

    private var pills: [PillItem] {
        var items: [PillItem] = []
        switch plan.status {
        case .reading:
            let pace = plan.pace()
            items.append(PillItem(text: "Day \(pace.dayNumber) of \(pace.plannedDays)", icon: .calendarBlank))
            items.append(PillItem(text: "\(StudyActions.chaptersText(pace.chaptersPerDay)) a day", icon: .bookOpen))
        case .upNext:
            items.append(PillItem(text: "\(plan.plannedDays) days", icon: .calendarBlank))
            items.append(PillItem(text: StudyActions.chaptersText(plan.totalChapters), icon: .bookOpen))
        case .done:
            items.append(PillItem(text: StudyActions.planLine(for: plan), icon: .checkCircle))
        }
        if plan.status != .done {
            items.append(PillItem(text: "\(plan.chaptersRead.count) read", icon: .check))
        }
        return items
    }
}

private struct BookCardPreviewList: View {
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            ForEach(plans) { BookCard(plan: $0) }
        }
    }
}

#Preview {
    ScrollView {
        BookCardPreviewList()
            .padding(Theme.Spacing.m)
    }
    .background { AppBackground() }
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

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

/// One study in the Study list: the picture (photo, illustration, or Selah reading), the book as a red pill, the
/// study title, a status line, and a light progress ring in glass at the top right.
struct BookCard: View {
    let plan: ReadingPlan

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var cardHeight: CGFloat = 188

    private var progress: Double {
        guard plan.totalChapters > 0 else { return 0 }
        return Double(plan.chaptersRead.count) / Double(plan.totalChapters)
    }

    private var statusLine: String {
        switch plan.status {
        case .reading:
            let pace = plan.pace()
            return "Day \(pace.dayNumber) of \(pace.plannedDays) \u{00B7} \(StudyActions.chaptersText(pace.chaptersPerDay)) a day"
        case .upNext:
            return "Up next \u{00B7} \(plan.plannedDays) days"
        case .done:
            return StudyActions.planLine(for: plan)
        }
    }

    private var summary: String {
        var parts = [plan.displayTitle, plan.bookName, StudyActions.progressText(for: plan), statusLine]
        if let reminders = StudyActions.remindersText(for: plan) { parts.append(reminders) }
        return parts.joined(separator: ". ")
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        // The picture is a background, so the card's size comes from its text (and the minimum height).
        return header
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, minHeight: typeSize.isAccessibilitySize ? nil : cardHeight, alignment: .topLeading)
            .background {
                ZStack {
                    StudyArtwork(plan: plan)
                    if StudyArtwork.hasPicture(plan) {
                        // Keeps the title readable over any picture: the card colour fading out from the top.
                        LinearGradient(
                            stops: [
                                .init(color: Theme.card.opacity(0.92), location: 0),
                                .init(color: Theme.card.opacity(0.6), location: 0.4),
                                .init(color: Theme.card.opacity(0), location: 0.7)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .accessibilityHidden(true)
            }
            .clipShape(shape)
        .selahCard()
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityHint("Opens the book page")
        .accessibilityIdentifier("book-card")
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                SelahPill(plan.bookName, style: .accent)
                Text(plan.displayTitle)
                    .font(.selahTitle)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusLine)
                    .font(.selahLabelSmall)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                ring
            }
        }
    }

    /// A light ring: thin, a pale track and the accent, on a small glass disc so it reads over any picture.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(plan.chaptersRead.count)/\(plan.totalChapters)")
                .font(.selahStatSmall)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(Theme.Spacing.xs)
        }
        .padding(5)
        .frame(width: ringSize, height: ringSize)
        .glassEffect(.regular, in: .circle)
        .accessibilityHidden(true)
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

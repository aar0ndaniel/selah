import SwiftUI
import SwiftData
import UIKit

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

/// One study in the Study list, laid out like the owner's reference: the picture fills a near-square card, the book
/// sits as a small translucent pill at the start of the title's first line, the title runs on in large white type and
/// wraps under the pill, and a light progress ring sits on a small Liquid Glass disc at the top right.
struct BookCard: View {
    let plan: ReadingPlan

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.displayScale) private var displayScale
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 46

    private var progress: Double {
        guard plan.totalChapters > 0 else { return 0 }
        return Double(plan.chaptersRead.count) / Double(plan.totalChapters)
    }

    private var statusLine: String {
        switch plan.status {
        case .reading:
            let pace = plan.pace()
            return "Day \(pace.dayNumber) of \(pace.plannedDays)"
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

    /// White type over a picture (as in the reference); the page's own text colour over the plain tint.
    private var onPicture: Bool { StudyArtwork.hasPicture(plan) }
    private var ink: Color { onPicture ? .white : .primary }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            titleText
            Text(statusLine)
                .font(.selahLabelSmall)
                .foregroundStyle(ink.opacity(0.85))
        }
        .shadow(color: onPicture ? .black.opacity(0.18) : .clear, radius: 6, x: 0, y: 1)
        .padding(.trailing, typeSize.isAccessibilitySize ? 0 : ringSize + Theme.Spacing.s)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(minHeight: typeSize.isAccessibilitySize ? nil : 300, alignment: .topLeading)
        .background {
            StudyArtwork(plan: plan)
                .accessibilityHidden(true)
        }
        .overlay(alignment: .topTrailing) {
            if !typeSize.isAccessibilitySize {
                ring
                    .padding(14)
            }
        }
        .clipShape(shape)
        // A glassy edge: a thin light rim like the reference card.
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.7), .white.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .contentShape(shape)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityHint("Opens the book page")
        .accessibilityIdentifier("book-card")
    }

    /// The pill and the title as one piece of text, so the title wraps under the pill like the reference.
    private var titleText: Text {
        let title = Text(plan.displayTitle)
            .font(.custom(SelahFontFamily.display, size: 26, relativeTo: .title).weight(.medium))
            .foregroundColor(ink)
        guard let pill = pillImage else { return title }
        return Text("\(Image(uiImage: pill)) ").baselineOffset(-3) + title
    }

    /// The book as a small rounded pill, drawn once to an image so it can sit inside the title's first line.
    @MainActor
    private var pillImage: UIImage? {
        let pill = Text(plan.bookName)
            .font(.custom(SelahFontFamily.body, size: 12, relativeTo: .caption).weight(.semibold))
            .foregroundStyle(onPicture ? Color.white : Theme.onAccent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(onPicture ? Color.white.opacity(0.28) : Theme.accent, in: Capsule())
        let renderer = ImageRenderer(content: pill)
        renderer.scale = displayScale
        return renderer.uiImage
    }

    /// A light ring: thin, a pale track and the accent, on a small Liquid Glass disc.
    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(plan.chaptersRead.count)/\(plan.totalChapters)")
                .font(.selahLabelSmall.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(6)
        }
        .padding(4)
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

import SwiftUI
import SwiftData

/// One book in the Study list. Flat surface card (not glass).
struct BookCard: View {
    let plan: ReadingPlan

    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 64

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
        SurfaceCard {
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
                : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
            layout {
                ProgressRing(
                    progress: progress,
                    lineWidth: 7,
                    centreLabel: "\(plan.chaptersRead.count)/\(plan.totalChapters)",
                    accessibilityLabel: "Chapters read",
                    accessibilityValue: StudyActions.progressText(for: plan)
                )
                .frame(width: ringSize, height: ringSize)

                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(plan.bookName)
                        .font(.headline)
                    Text(StudyActions.progressText(for: plan))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(StudyActions.planLine(for: plan))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let reminders = StudyActions.remindersText(for: plan) {
                        PLabel(reminders, icon: .bell, size: 14, textStyle: .footnote)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if !typeSize.isAccessibilitySize {
                    PIconView(.caretRight, size: 14, relativeTo: .footnote)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary)
        .accessibilityHint("Opens book details")
        .accessibilityIdentifier("book-card")
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

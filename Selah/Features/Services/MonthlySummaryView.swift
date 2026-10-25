import SwiftUI
import SwiftData

extension ServiceSnapshot {
    /// Copies the values the summary needs out of a SwiftData object.
    @MainActor
    init(_ service: Service) {
        let parts = service.orderedParts.filter { $0.hasContent }
        func talks(_ kind: ServicePartKind) -> [TalkSnapshot] {
            parts.filter { $0.kind == kind }.map { TalkSnapshot(title: $0.title, person: $0.person) }
        }
        self.init(
            date: service.date,
            gatheringName: service.gatheringName,
            sermons: talks(.sermon),
            classes: talks(.bibleClass),
            verseBooks: parts.flatMap { $0.verses.map { $0.book } },
            songs: parts.filter { $0.kind == .song }.map { part in
                // A song typed with only a number still shows its library title.
                let title = part.title.trimmingCharacters(in: .whitespacesAndNewlines)
                return SongSnapshot(
                    hymnNumber: part.songType == .hymn ? part.hymnNumber : "",
                    title: title.isEmpty ? (part.librarySong?.title ?? "") : title
                )
            }
        )
    }
}

/// The Monthly segment: a month switcher and the counts, lists and rankings for that month.
struct MonthlySummaryView: View {
    let services: [Service]
    /// Offered from the empty state when the screen can create a service (not from Settings).
    var onNewService: (() -> Void)? = nil

    @State private var month = MonthlySummary.monthStart(for: Date())

    private var currentSummary: MonthlySummary {
        MonthlySummary(services: services.map { ServiceSnapshot($0) }, month: month)
    }

    private var monthLabel: String {
        month.formatted(.dateTime.month(.wide).year())
    }

    var body: some View {
        let data = currentSummary
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            monthSwitcher

            if data.isEmpty {
                EmptyState(
                    title: "No services in \(monthLabel)",
                    icon: .calendarBlank,
                    message: "Services you record this month will be counted here.",
                    actionTitle: onNewService == nil ? nil : "New service for today",
                    action: onNewService
                )
            } else {
                HStack {
                    Spacer()
                    exportMenu(for: data)
                }
                statTiles(data)
                if !data.sermons.isEmpty { sermonList(data) }
                if !data.classes.isEmpty { classList(data) }
                if !data.booksQuoted.isEmpty { booksCard(data) }
                if !data.songsSung.isEmpty { songsCard(data) }
            }
        }
        .padding(.horizontal, Theme.Spacing.m)
    }

    // MARK: Export

    private func exportMenu(for data: MonthlySummary) -> some View {
        let items = services.map { ServiceExportItem($0) }
        let baseName = ExportService.monthlyFileName(summary: data, ext: "pdf")
            .replacingOccurrences(of: ".pdf", with: "")
        return ExportMenu(title: "Export", baseFileName: baseName) {
            ExportService.monthlyDocument(summary: data, services: items)
        }
    }

    // MARK: Month switcher

    private var monthSwitcher: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(picon: .caretLeft)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(monthLabel)
                .font(.selahTitle)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(picon: .caretRight)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Next month")
        }
        .sensoryFeedback(.selection, trigger: month)
    }

    private func shiftMonth(by value: Int) {
        let shifted = Calendar.current.date(byAdding: .month, value: value, to: month) ?? month
        month = MonthlySummary.monthStart(for: shifted)
    }

    // MARK: Stat tiles

    private func statTiles(_ summary: MonthlySummary) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 140), spacing: Theme.Spacing.s)],
            spacing: Theme.Spacing.s
        ) {
            tile(count: summary.serviceCount, singular: "Service", plural: "Services", tone: .sky)
            tile(count: summary.sermonCount, singular: "Sermon", plural: "Sermons", tone: .sky)
            tile(count: summary.classCount, singular: "Bible class", plural: "Bible classes", tone: .sage)
            tile(count: summary.songCount, singular: "Song", plural: "Songs", tone: .coral)
        }
    }

    private func tile(count: Int, singular: String, plural: String, tone: Tone) -> some View {
        let label = count == 1 ? singular : plural
        return ToneCard(tone: tone) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(count)")
                    .font(.selahStat)
                    .foregroundStyle(tone.onSurface)
                    .contentTransition(.numericText())
                Text(label)
                    .font(.selahLabel)
                    .foregroundStyle(tone.inkSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) \(label.lowercased())")
    }

    // MARK: Lists

    private func sermonList(_ summary: MonthlySummary) -> some View {
        section("Sermons") {
            ForEach(Array(summary.sermons.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                itemRow(
                    title: item.title.isEmpty ? "Untitled sermon" : item.title,
                    detail: item.sermonist,
                    date: item.date
                )
            }
        }
    }

    private func classList(_ summary: MonthlySummary) -> some View {
        section("Bible classes") {
            ForEach(Array(summary.classes.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                itemRow(
                    title: item.lesson.isEmpty ? "Untitled lesson" : item.lesson,
                    detail: item.teacher.isEmpty ? "" : "Taught by \(item.teacher)",
                    date: item.date
                )
            }
        }
    }

    /// Books quoted most: a title, a tone card and one simple horizontal bar per book.
    private func booksCard(_ summary: MonthlySummary) -> some View {
        let tone = Tone.sky
        let maxCount = max(summary.booksQuoted.map { $0.count }.max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Books quoted most")
                .font(.selahCardTitle)
                .accessibilityAddTraits(.isHeader)
            ToneCard(tone: tone) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(Array(summary.booksQuoted.enumerated()), id: \.offset) { _, item in
                        bookBar(item, maxCount: maxCount, tone: tone)
                    }
                }
            }
        }
    }

    private func bookBar(_ item: MonthlySummary.BookCount, maxCount: Int, tone: Tone) -> some View {
        let times = item.count == 1 ? "1 time" : "\(item.count) times"
        return VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                Text(item.book)
                    .font(.selahHeadline)
                    .foregroundStyle(tone.onSurface)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(times)
                    .font(.selahLabel)
                    .foregroundStyle(tone.inkSecondary)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(tone.ink.opacity(0.15))
                    Capsule()
                        .fill(tone.ink)
                        .frame(width: max(proxy.size.width * CGFloat(item.count) / CGFloat(maxCount), 8))
                }
            }
            .frame(height: 8)
            .accessibilityHidden(true)
        }
        .frame(minHeight: Theme.minTapTarget)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.book), \(times)")
    }

    private func songsCard(_ summary: MonthlySummary) -> some View {
        section("Songs sung") {
            ForEach(Array(summary.songsSung.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                countRow(title: songTitle(item), count: item.count)
            }
        }
    }

    private func songTitle(_ item: MonthlySummary.SongCount) -> String {
        switch (item.hymnNumber.isEmpty, item.title.isEmpty) {
        case (false, false): return "Hymn \(item.hymnNumber), \(item.title)"
        case (false, true): return "Hymn \(item.hymnNumber)"
        default: return item.title
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.selahCardTitle)
                .accessibilityAddTraits(.isHeader)
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    content()
                }
            }
        }
    }

    private func itemRow(title: String, detail: String, date: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(title)
                .font(.selahHeadline)
            if !detail.isEmpty {
                Text(detail)
                    .font(.selahLabel)
                    .foregroundStyle(.secondary)
            }
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.selahLabelSmall)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func countRow(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.selahBody)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(count == 1 ? "1 time" : "\(count) times")
                .font(.selahLabel)
                .foregroundStyle(.secondary)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(count == 1 ? "1 time" : "\(count) times")")
    }
}

private struct MonthlySummaryPreview: View {
    @Query(sort: \Service.date) private var services: [Service]

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                MonthlySummaryView(services: services)
            }
        }
    }
}

#Preview {
    MonthlySummaryPreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

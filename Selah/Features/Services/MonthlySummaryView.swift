import SwiftUI
import SwiftData

extension ServiceSnapshot {
    /// Copies the values the summary needs out of a SwiftData object.
    @MainActor
    init(_ service: Service) {
        self.init(
            date: service.date,
            gatheringName: service.gatheringName,
            sermonTitle: service.sermonTitle,
            sermonist: service.sermonist,
            classLesson: service.classLesson,
            classTeacher: service.classTeacher,
            verseBooks: service.verses.map { $0.book },
            songs: service.songs.map { SongSnapshot(hymnNumber: $0.hymnNumber, title: $0.title) }
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
                    systemImage: "calendar",
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
                Image(systemName: "chevron.left")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Previous month")

            Spacer()
            Text(monthLabel)
                .font(.headline)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
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
            tile(count: summary.serviceCount, singular: "Service", plural: "Services")
            tile(count: summary.sermonCount, singular: "Sermon", plural: "Sermons")
            tile(count: summary.classCount, singular: "Bible class", plural: "Bible classes")
            tile(count: summary.songCount, singular: "Song", plural: "Songs")
        }
    }

    private func tile(count: Int, singular: String, plural: String) -> some View {
        let label = count == 1 ? singular : plural
        return SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("\(count)")
                    .font(.title.weight(.semibold))
                    .contentTransition(.numericText())
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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

    private func booksCard(_ summary: MonthlySummary) -> some View {
        section("Books quoted most") {
            ForEach(Array(summary.booksQuoted.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                countRow(title: item.book, count: item.count)
            }
        }
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
                .font(.headline)
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
                .font(.body)
            if !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func countRow(title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(title)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(count == 1 ? "1 time" : "\(count) times")
                .font(.subheadline)
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

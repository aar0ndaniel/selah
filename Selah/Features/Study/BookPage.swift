import SwiftUI
import SwiftData

/// Where to go when a day or a note is tapped. Holds the note's ID (not the model) so it stays valid
/// whatever happens to the model while the page is on screen.
struct EntryRoute: Hashable {
    /// nil means a new note that is only saved when the reader taps Save.
    let entryID: PersistentIdentifier?
    let date: Date
}

/// A book as a full page: banner and title, plan calendar, today's note, the notes so far, chapters.
/// Pushed from the Study list. Plan settings live behind the "…" menu (Edit plan).
struct BookPage: View {
    @Bindable var plan: ReadingPlan
    /// Called when the reader confirms deleting. The parent deletes after this page has been popped.
    let onDelete: (ReadingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 72

    @State private var route: EntryRoute?
    @State private var showEdit = false
    @State private var confirmDelete = false
    @State private var entryToDelete: StudyEntry?
    @State private var isRemoved = false
    @State private var shareItem: ShareItem?
    @State private var showExportError = false
    @State private var chaptersExpanded = false

    private var tone: Tone { plan.cardTone }

    private var sortedEntries: [StudyEntry] {
        plan.entries.sorted { $0.date > $1.date }
    }

    private var progress: Double {
        guard plan.totalChapters > 0 else { return 0 }
        return Double(plan.chaptersRead.count) / Double(plan.totalChapters)
    }

    private var todayEntry: StudyEntry? {
        StudyActions.entry(on: Date(), in: plan)
    }

    private var planCalendar: PlanCalendar? {
        guard let start = plan.startDate else { return nil }
        return PlanCalendar(
            start: start,
            plannedDays: plan.plannedDays,
            entryDates: plan.entries.map(\.date)
        )
    }

    var body: some View {
        Group {
            if isRemoved {
                AppBackground()
            } else {
                page
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .hidesPlusButton()
    }

    private var page: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                todayButton
                notesSection
                calendarSection
                chaptersSection
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background { AppBackground() }
        .navigationTitle(plan.bookName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                moreMenu
            }
        }
        .navigationDestination(item: $route) { route in
            EntryPage(plan: plan, entry: entry(for: route), date: route.date)
        }
        .sheet(isPresented: $showEdit) {
            EditPlanSheet(plan: plan)
        }
        .sheet(item: $shareItem) { item in
            ShareSheet(items: item.items)
                .presentationDetents([.medium, .large])
        }
        .alert("Couldn't export", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Tehila couldn't make the file. Please try again.")
        }
        .confirmationDialog(
            "Delete \(plan.bookName)?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete book", role: .destructive) {
                isRemoved = true
                onDelete(plan)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Its notes and reminders are deleted too.")
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(
                get: { entryToDelete != nil },
                set: { if !$0 { entryToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete note", role: .destructive) {
                if let entry = entryToDelete { modelContext.delete(entry) }
                entryToDelete = nil
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        }
        .sensoryFeedback(.selection, trigger: plan.chaptersRead)
    }

    private func entry(for route: EntryRoute) -> StudyEntry? {
        guard let id = route.entryID else { return nil }
        return plan.entries.first { $0.persistentModelID == id }
    }

    // MARK: Menu

    private var moreMenu: some View {
        Menu {
            Button {
                showEdit = true
            } label: {
                Label("Edit plan", picon: .pencilSimple)
            }
            Menu {
                Button {
                    exportPDF()
                } label: {
                    Label("PDF", picon: .filePdf)
                }
                Button {
                    shareItem = ShareItem(items: [exportDocument().plainText])
                } label: {
                    Label("Plain text", picon: .textAlignLeft)
                }
            } label: {
                Label("Export entries", picon: .export)
            }
            .disabled(plan.entries.isEmpty)
            Divider()
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete book", picon: .trash)
            }
        } label: {
            Image(picon: .dotsThree)
        }
        .accessibilityLabel("More actions")
    }

    private func exportDocument() -> ExportDocument {
        ExportService.bookDocument(BookExportItem(plan))
    }

    private func exportPDF() {
        let name = ExportService.bookFileName(plan.bookName, ext: "pdf")
        Task { @MainActor in
            await Task.yield()
            do {
                let url = try ExportService.writePDF(exportDocument(), fileName: name)
                shareItem = ShareItem(items: [url])
            } catch {
                showExportError = true
            }
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 0) {
            if let data = plan.bannerData {
                BannerImageView(data: data, height: 180)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text(plan.bookName)
                    .font(.selahDisplay)
                    .foregroundStyle(tone.onSurface)
                    .accessibilityAddTraits(.isHeader)

                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.s))
                    : AnyLayout(HStackLayout(spacing: Theme.Spacing.m))
                layout {
                    ring
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(StudyActions.progressText(for: plan))
                            .font(.selahLabel)
                            .foregroundStyle(tone.inkSecondary)
                        FlowLayout(spacing: Theme.Spacing.xs) {
                            ForEach(pills, id: \.text) { pill in
                                CardPill(text: pill.text, icon: pill.icon, tone: tone)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(tone.fill)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    private var ring: some View {
        ZStack {
            Circle().fill(Color(.systemBackground).opacity(0.6))
            ProgressRing(
                progress: progress,
                lineWidth: 7,
                tone: tone,
                centreLabel: "\(plan.chaptersRead.count)/\(plan.totalChapters)",
                accessibilityLabel: "Chapters read",
                accessibilityValue: StudyActions.progressText(for: plan)
            )
            .foregroundStyle(tone.ink)
            .padding(6)
        }
        .frame(width: ringSize, height: ringSize)
    }

    private struct PillItem {
        let text: String
        let icon: PIcon
    }

    private var pills: [PillItem] {
        var items: [PillItem] = []
        switch plan.status {
        case .reading:
            let pace = plan.pace()
            items.append(PillItem(text: "Day \(pace.dayNumber) of \(pace.plannedDays)", icon: .calendarBlank))
            items.append(PillItem(text: "\(StudyActions.chaptersText(pace.chaptersPerDay)) a day", icon: .bookOpen))
        case .upNext:
            items.append(PillItem(text: "Up next", icon: .bookmarkSimple))
            items.append(PillItem(text: "\(plan.plannedDays) days", icon: .calendarBlank))
        case .done:
            items.append(PillItem(text: StudyActions.planLine(for: plan), icon: .checkCircle))
        }
        if let reminders = StudyActions.remindersText(for: plan) {
            items.append(PillItem(text: reminders, icon: .bell))
        }
        return items
    }

    // MARK: Today

    private var todayButton: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Button {
                openDay(Date())
            } label: {
                PLabel(
                    todayEntry == nil ? "Write today's note" : "Open today's note",
                    icon: .notePencil
                )
            }
            .buttonStyle(.selahPrimaryFull)
            .accessibilityIdentifier("today-note-button")
            Text(todayEntry == nil ? "Nothing written for today yet." : "Today's note is saved.")
                .font(.selahLabelSmall)
                .foregroundStyle(.secondary)
        }
    }

    private func openDay(_ day: Date) {
        let existing = StudyActions.entry(on: day, in: plan)
        let date = planCalendar?.entryDate(for: day) ?? day
        route = EntryRoute(entryID: existing?.persistentModelID, date: existing?.date ?? date)
    }

    // MARK: Calendar

    @ViewBuilder
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Plan calendar")
                .font(.selahTitle)
                .accessibilityAddTraits(.isHeader)
            SurfaceCard {
                if let planCalendar {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        PlanCalendarView(plan: planCalendar, tone: tone) { day in
                            openDay(day)
                        }
                        Text(planRangeText(planCalendar))
                            .font(.selahLabelSmall)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("The calendar starts on the day you start this book.")
                            .font(.selahBody)
                        Button("Start reading today") {
                            StudyActions.startReading(plan)
                        }
                        .buttonStyle(.selahSecondary(tone: tone))
                    }
                }
            }
        }
    }

    private func planRangeText(_ calendar: PlanCalendar) -> String {
        let format = Date.FormatStyle.dateTime.day().month(.abbreviated)
        return "\(plan.plannedDays) \(plan.plannedDays == 1 ? "day" : "days"): \(calendar.start.formatted(format)) to \(calendar.end.formatted(format))"
    }

    // MARK: Chapters

    private var chaptersSection: some View {
        SurfaceCard {
            DisclosureGroup(isExpanded: $chaptersExpanded) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? circleSize + 16 : circleSize), spacing: Theme.Spacing.xs)],
                        spacing: Theme.Spacing.xs
                    ) {
                        ForEach(1...max(plan.totalChapters, 1), id: \.self) { chapter in
                            chapterCircle(chapter)
                        }
                    }
                    Text("Tap a chapter to mark it read or not read.")
                        .font(.selahLabelSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.Spacing.s)
            } label: {
                Text("Chapters \u{00B7} \(plan.chaptersRead.count) of \(plan.totalChapters) read")
                    .font(.selahTitle)
                    .accessibilityAddTraits(.isHeader)
            }
            .tint(.secondary)
        }
    }

    private func chapterCircle(_ chapter: Int) -> some View {
        let isRead = plan.chaptersRead.contains(chapter)
        return Button {
            StudyActions.toggleChapter(chapter, in: plan)
        } label: {
            VStack(spacing: 0) {
                if isRead {
                    PIconView(.check, size: 12, relativeTo: .caption2)
                        .font(.selahEyebrow.weight(.bold))
                }
                Text("\(chapter)")
                    .font(.selahLabel.weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            // Deep teal in light mode, bright teal in dark mode: the surface colour keeps the tick readable in both.
            .foregroundStyle(isRead ? Color(.systemBackground) : Color.primary)
            .frame(width: circleSize, height: circleSize)
            .background(
                Circle().fill(isRead ? Color.accentColor : Color(.tertiarySystemFill))
            )
            .overlay(
                Circle().strokeBorder(Color.accentColor.opacity(isRead ? 0 : 0.5), lineWidth: 1)
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chapter \(chapter), \(isRead ? "read" : "not read")")
        .accessibilityAddTraits(isRead ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Notes so far

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("Notes so far")
                    .font(.selahTitle)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if !plan.entries.isEmpty {
                    Pill(text: "\(plan.entries.count)", icon: .notePencil, tone: tone)
                        .accessibilityLabel("\(plan.entries.count) notes")
                }
            }
            if sortedEntries.isEmpty {
                SurfaceCard {
                    Text("No notes yet. Tap a day in the calendar, or write today's note.")
                        .font(.selahBody)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(sortedEntries) { entry in
                    Button {
                        route = EntryRoute(entryID: entry.persistentModelID, date: entry.date)
                    } label: {
                        noteRow(entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            entryToDelete = entry
                        } label: {
                            Label("Delete note", picon: .trash)
                        }
                    }
                }
            }
        }
    }

    private func noteRow(_ entry: StudyEntry) -> some View {
        let dateText = entry.date.formatted(date: .abbreviated, time: .omitted)
        let firstLine = StudyActions.firstLine(of: entry.note)
        return SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(dateText)
                        .font(.selahLabel.weight(.semibold))
                    Spacer()
                    Pill(text: "Chapter \(entry.chapter)", icon: .bookOpen, tone: tone)
                }
                if let verse = entry.bestVerse {
                    Text(verse.textSnapshot)
                        .font(.selahVerseCompact)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    Text(verse.reference)
                        .font(.selahLabelSmall)
                        .foregroundStyle(.secondary)
                }
                if !firstLine.isEmpty {
                    Text(firstLine)
                        .font(.selahLabel)
                        .foregroundStyle(.secondary)
                        .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(dateText), chapter \(entry.chapter)"
            + (entry.bestVerse.map { ", best verse \($0.reference)" } ?? "")
            + (firstLine.isEmpty ? "" : ". \(firstLine)")
        )
        .accessibilityHint("Opens the note")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Delete note") { entryToDelete = entry }
    }
}

private struct BookPagePreview: View {
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            NavigationStack {
                BookPage(plan: plan) { _ in }
            }
        }
    }
}

#Preview {
    BookPagePreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

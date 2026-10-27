import SwiftUI
import SwiftData

/// Where to go when a day or a note is tapped. Holds the note's ID (not the model) so it stays valid
/// whatever happens to the model while the page is on screen.
struct EntryRoute: Hashable {
    /// nil means a new note that is only saved when the reader taps Save.
    let entryID: PersistentIdentifier?
    let date: Date
}

/// A study as a full page: the hero card (progress, book, title, description, today's note), the notes so far,
/// the plan calendar and the chapters.
/// Pushed from the Study list. Plan settings live behind the "…" menu (Edit plan).
struct BookPage: View {
    @Bindable var plan: ReadingPlan
    /// Called when the reader confirms deleting. The parent deletes after this page has been popped.
    let onDelete: (ReadingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 44

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
                hero
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

    // MARK: Hero

    /// The study at a glance: overall progress on the tinted top strip, the white card with the book, the study
    /// title, its description, today's note button and the day count, then whether today's note is saved.
    private var hero: some View {
        VStack(spacing: 0) {
            progressStrip
            mainCard
                .padding(.horizontal, 6)
            todayStrip
        }
        .background(Theme.brandFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var percentText: String { "\(Int((progress * 100).rounded()))%" }

    private var progressStrip: some View {
        HStack(spacing: Theme.Spacing.s) {
            ZStack {
                Circle()
                    .stroke(Theme.brandInk.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(max(progress, 0), 1))
                    .stroke(Theme.brandInk, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            Text("Overall progress")
                .font(.selahLabel)
                .foregroundStyle(Theme.brandInk)
            Spacer(minLength: Theme.Spacing.s)
            Text(percentText)
                .font(.selahStatSmall)
                .foregroundStyle(Theme.brandInk)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Overall progress")
        .accessibilityValue("\(percentText). \(StudyActions.progressText(for: plan))")
    }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(plan.title.trimmingCharacters(in: .whitespaces).isEmpty ? "Bible study" : plan.bookName)
                .font(.selahLabel)
                .foregroundStyle(.secondary)
            Text(plan.displayTitle)
                .font(.selahDisplay)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            let summary = plan.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                Text(summary)
                    .font(.selahBody)
                    .foregroundStyle(.secondary)
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
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .selahCard(radius: 22)
    }

    /// The coral button: start the book, write today's note, or open it.
    private var todayButton: some View {
        Button {
            if plan.startDate == nil {
                StudyActions.startReading(plan)
            } else {
                openDay(Date())
            }
        } label: {
            PLabel(todayButtonTitle, icon: plan.startDate == nil ? .bookOpen : .notePencil, size: 18)
                .font(.selahButton)
                .foregroundStyle(Theme.onAccent)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget)
                .background(Theme.accent, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("today-note-button")
    }

    private var todayButtonTitle: String {
        if plan.startDate == nil { return "Start reading" }
        return todayEntry == nil ? "Write today's note" : "Open today's note"
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

    /// Day count with the reminder bell: on or off, no time (times are set in Edit plan).
    private var dayInfo: some View {
        HStack(spacing: Theme.Spacing.xs) {
            PIconView(hasReminders ? .bell : .bellSlash, size: 16, relativeTo: .subheadline)
            Text(dayText)
                .font(.selahLabel.weight(.semibold))
                .monospacedDigit()
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayText.replacingOccurrences(of: "/", with: " of ")), reminders \(hasReminders ? "on" : "off")")
    }

    private var todayStatus: (icon: PIcon, text: String) {
        switch plan.status {
        case .upNext:
            return (.bookmarkSimple, "Not started yet")
        case .done:
            return (.checkCircle, StudyActions.planLine(for: plan))
        case .reading:
            return todayEntry == nil
                ? (.notePencil, "Today's note isn't written yet")
                : (.checkCircle, "Today's note is saved")
        }
    }

    private var todayStrip: some View {
        let status = todayStatus
        return HStack(spacing: Theme.Spacing.s) {
            PIconView(status.icon, size: 16, relativeTo: .subheadline)
            Text(status.text)
                .font(.selahLabel)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.brandInk)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .accessibilityElement(children: .combine)
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
                    SelahPill("\(plan.entries.count)", icon: .notePencil, style: .accent)
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

    /// A compact note card: the chapter as a red pill beside the verse (or the note's first line), what was written
    /// greyed underneath on one line, then the date and the verse reference.
    private func noteRow(_ entry: StudyEntry) -> some View {
        let dateText = entry.date.formatted(.dateTime.day().month(.abbreviated))
        let firstLine = StudyActions.firstLine(of: entry.note)
        let verse = entry.bestVerse
        let title = verse?.textSnapshot ?? (firstLine.isEmpty ? "Chapter \(entry.chapter) note" : firstLine)
        let greyed = verse == nil ? "" : firstLine
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                SelahPill("Chapter \(entry.chapter)", style: .accent)
                Text(title)
                    .font(.selahHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !greyed.isEmpty {
                Text(greyed)
                    .font(.selahLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 1)
            }
            HStack(spacing: Theme.Spacing.s) {
                PLabel(dateText, icon: .calendarBlank, size: 14, textStyle: .footnote)
                if let verse {
                    PLabel(verse.reference, icon: .bookOpen, size: 14, textStyle: .footnote)
                        .lineLimit(1)
                }
            }
            .font(.selahLabelSmall)
            .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .selahCard()
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Chapter \(entry.chapter), \(dateText)"
            + (verse.map { ", \($0.reference): \($0.textSnapshot)" } ?? "")
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

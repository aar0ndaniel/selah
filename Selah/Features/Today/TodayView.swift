import SwiftUI
import SwiftData

/// Full-screen pages Today can open (editors are pages, not sheets).
private enum TodayCover: Identifiable {
    case entry(ReadingPlan, StudyEntry?)
    case service(Service)

    var id: String {
        switch self {
        case .entry(let plan, _): return "entry-\(plan.persistentModelID.hashValue)"
        case .service(let service): return "service-\(service.persistentModelID.hashValue)"
        }
    }
}

private enum RecentTarget {
    case study(StudyEntry, ReadingPlan)
    case service(Service)
    case personal(PersonalNote)
}

private struct RecentNote: Identifiable {
    let item: NoteItem
    let target: RecentTarget
    var id: String { item.id }
}

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Quiet time state shared with the App Intents. Reading it in `body` makes the banner appear and go away.
    private let quiet = QuietIntentRouter.shared

    @Query private var profiles: [UserProfile]
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]
    @Query(sort: \StudyEntry.date, order: .reverse) private var entries: [StudyEntry]
    @Query(sort: \Service.date, order: .reverse) private var services: [Service]
    @Query(sort: \PersonalNote.updatedAt, order: .reverse) private var personalNotes: [PersonalNote]
    @Query private var meetingDays: [MeetingDay]

    @State private var cover: TodayCover?
    @State private var showVersePicker = false
    @State private var showSettings = false
    @State private var openNote: PersonalNote?

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 76
    @ScaledMetric(relativeTo: .body) private var badgeSize: CGFloat = 68
    @State private var heatmapYear = Calendar.current.component(.year, from: Date())

    /// Which streak Today shows; chosen in Settings.
    @AppStorage(StreakKind.storageKey) private var streakKindRaw = StreakKind.study.rawValue
    private var streakKind: StreakKind { StreakKind(rawValue: streakKindRaw) ?? .study }

    private var profile: UserProfile? { profiles.first }
    private var translation: Translation { profile?.translation ?? .kjv }

    private var readingPlans: [ReadingPlan] { plans.filter { $0.status == .reading } }

    private func entryToday(for plan: ReadingPlan) -> StudyEntry? {
        plan.entries
            .filter { Calendar.current.isDateInToday($0.date) }
            .max { $0.createdAt < $1.createdAt }
    }

    /// Today's entry that carries a verse, from any book.
    private var verseEntryToday: StudyEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) && $0.bestVerse != nil }
    }

    private var greeting: String {
        let name = profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Welcome back" : "Hello, \(name)"
    }

    /// Plain values for the streak rules.
    private var streakInput: StreakInput {
        var spans: [ReadingSpan] = []
        for plan in plans where plan.status != .upNext {
            let dates = plan.entries.map { $0.date }
            guard let start = plan.startDate ?? dates.min() else { continue }
            let end: Date? = plan.status == .done ? (plan.finishedDate ?? dates.max() ?? start) : nil
            spans.append(ReadingSpan(start: start, end: end))
        }
        return StreakInput(
            studyDates: entries.map { $0.date },
            serviceDates: services.map { $0.date },
            meetingWeekdays: Set(meetingDays.filter { $0.isActive }.map { $0.weekday }),
            readingSpans: spans
        )
    }

    /// The celebration plays only while Today is really in front of the user.
    private var streaksAreVisible: Bool {
        router.selectedTab == .today && cover == nil && !showVersePicker && !showSettings && openNote == nil
    }

    // MARK: Body

    var body: some View {
        let now = Date()
        let input = streakInput
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header(now: now)
                    if quiet.isQuietTimeOn {
                        QuietTimeBanner(onEnd: { quiet.endQuietTime() })
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                    StreakSection(
                        kind: streakKind,
                        summary: Streaks.summary(input, today: now),
                        today: now,
                        isActive: streaksAreVisible
                    )
                    verseCard
                    readingSection(now: now)
                    gatheringSection(now: now)
                    readingHeatmap(now: now)
                    recentNotesSection
                }
                .padding(.horizontal, Theme.Spacing.m)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: quiet.isQuietTimeOn)
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .background { AppBackground() }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        AvatarView(photoData: profile?.photoData, size: 32)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Profile and settings")
                    .accessibilityIdentifier("profile-button")
                }
            }
            .navigationDestination(item: $openNote) { note in
                PersonalNotePage(note: note, isNew: false)
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(isPresented: $showVersePicker) {
            VersePicker(translation: translation) { setTodayVerse($0) }
        }
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .entry(let plan, let entry):
                EntrySheet(plan: plan, entry: entry)
            case .service(let service):
                ServiceSheet(service: service)
            }
        }
        .onChange(of: router.pendingAction) { _, _ in
            handlePendingAction()
        }
        .onAppear {
            handlePendingAction()
        }
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .selahEyebrow()
            Text(greeting)
                .font(.selahTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: Verse of the day

    @ViewBuilder
    private var verseCard: some View {
        if let verse = verseEntryToday?.bestVerse {
            let reference = "\(verse.reference) (\(verse.translation.shortName))"
            ToneCard(tone: .sand, padding: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack(alignment: .center) {
                        PIconView(.quotes, filled: true, size: 30, relativeTo: .largeTitle)
                            .foregroundStyle(Tone.sand.ink)
                        Spacer(minLength: 0)
                        Text("Verse of the day")
                            .font(.selahEyebrow)
                            .textCase(.uppercase)
                            .tracking(1.0)
                            .foregroundStyle(Tone.sand.inkSecondary)
                            .accessibilityAddTraits(.isHeader)
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text(verse.textSnapshot)
                            .font(.selahVerse)
                            .lineSpacing(4)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        OnCardPill(text: reference, tone: .sand)
                    }
                    .accessibilityElement(children: .combine)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.s) {
                            shareButton(text: verse.textSnapshot, reference: reference)
                            changeVerseButton
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            shareButton(text: verse.textSnapshot, reference: reference)
                            changeVerseButton
                        }
                    }
                }
            }
        } else if plans.isEmpty {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Verse of the day")
                        .font(.selahCardTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text("Start a book in Study first")
                        .font(.selahBody)
                    Button("Go to Study") { router.selectedTab = .study }
                        .buttonStyle(.selahSecondary(tone: .sand))
                }
            }
        } else {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    Text("Verse of the day")
                        .font(.selahCardTitle)
                        .accessibilityAddTraits(.isHeader)
                    Text("Pick a verse that spoke to you today.")
                        .font(.selahBody)
                    Button("Choose today's verse") {
                        if readingPlans.isEmpty {
                            router.selectedTab = .study
                        } else {
                            showVersePicker = true
                        }
                    }
                    .buttonStyle(.selahSecondary(tone: .sand))
                }
            }
        }
    }

    private func shareButton(text: String, reference: String) -> some View {
        ShareLink(item: "\(text) \u{2014} \(reference)") {
            Label("Share", picon: .export)
                .font(.selahLabel.weight(.semibold))
                .foregroundStyle(Tone.sand.ink)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget)
                .background(Color(.systemBackground).opacity(0.6), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Share verse")
    }

    private var changeVerseButton: some View {
        Button("Change verse") { showVersePicker = true }
            .buttonStyle(.selahTertiary)
    }

    // MARK: Today's reading

    @ViewBuilder
    private func readingSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle("Today's reading")
            if readingPlans.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("No book in progress")
                            .font(.selahHeadline)
                        Text("Start a book in Study and it will show up here each day.")
                            .font(.selahLabel)
                            .foregroundStyle(.secondary)
                        Button("Go to Study") { router.selectedTab = .study }
                            .buttonStyle(.selahSecondary())
                    }
                }
            } else {
                ForEach(readingPlans) { plan in
                    readingCard(for: plan, now: now)
                }
            }
        }
    }

    @ViewBuilder
    private func readingCard(for plan: ReadingPlan, now: Date) -> some View {
        let existing = entryToday(for: plan)
        let snapshot = ReadingSnapshot(
            bookName: plan.bookName,
            status: plan.status,
            chaptersRead: plan.chaptersRead,
            totalChapters: plan.totalChapters,
            plannedDays: plan.plannedDays,
            startDate: plan.startDate
        )
        if let item = TodaySummary.readingItem(for: snapshot, hasEntryToday: existing != nil, now: now) {
            let tone = plan.cardTone
            let total = max(plan.totalChapters, 1)
            let read = plan.chaptersRead.count
            ToneCard(tone: tone) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    HStack(alignment: .center, spacing: Theme.Spacing.m) {
                        ZStack {
                            Circle().fill(Color(.systemBackground).opacity(0.65))
                            ProgressRing(
                                progress: Double(read) / Double(total),
                                lineWidth: 7,
                                tone: tone,
                                centreLabel: "\(read)/\(total)",
                                accessibilityLabel: "Chapters read",
                                accessibilityValue: "\(read) of \(total) chapters"
                            )
                            .padding(Theme.Spacing.xxs)
                        }
                        .frame(width: ringSize, height: ringSize)

                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(item.bookName)
                                .font(.selahCardTitle)
                                .foregroundStyle(tone.onSurface)
                            Text(item.nextText)
                                .font(.selahLabel)
                                .foregroundStyle(.primary)
                            if let reminders = StudyActions.remindersText(for: plan) {
                                Text(reminders)
                                    .font(.selahLabelSmall)
                                    .foregroundStyle(tone.inkSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: Theme.Spacing.xs) {
                            OnCardPill(text: item.dayText, icon: .calendarBlank, tone: tone)
                            OnCardPill(text: item.paceText, icon: .bookOpen, tone: tone)
                        }
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            OnCardPill(text: item.dayText, icon: .calendarBlank, tone: tone)
                            OnCardPill(text: item.paceText, icon: .bookOpen, tone: tone)
                        }
                    }

                    Button {
                        cover = .entry(plan, existing)
                    } label: {
                        Text(item.hasEntryToday ? "Open today's note" : "Write today's note")
                    }
                    .buttonStyle(.selahPrimaryFull)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        }
    }

    // MARK: Next gathering

    private func gatheringSection(now: Date) -> some View {
        let slots = meetingDays.map {
            MeetingSlot(name: $0.name, weekday: $0.weekday, hour: $0.hour, minute: $0.minute, isActive: $0.isActive)
        }
        let next = TodaySummary.nextGathering(from: slots, now: now)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle("Next gathering")
            if let next {
                gatheringCard(next, now: now)
            } else {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("No meeting days yet")
                            .font(.selahHeadline)
                        Text("Add the days you meet in Settings and the next one will show here.")
                            .font(.selahLabel)
                            .foregroundStyle(.secondary)
                        Button("Open settings") { showSettings = true }
                            .buttonStyle(.selahSecondary())
                    }
                }
            }
        }
    }

    private func gatheringCard(_ next: NextGathering, now: Date) -> some View {
        let tone = Tone.slate
        let calendar = Calendar.current
        let timeText = StudyActions.timeText(
            hour: calendar.component(.hour, from: next.date),
            minute: calendar.component(.minute, from: next.date)
        )
        let countdown = GatheringCountdown.text(
            daysAway: GatheringCountdown.daysAway(from: now, to: next.date),
            todayText: next.text
        )
        return ToneCard(tone: tone) {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                HStack(alignment: .center, spacing: Theme.Spacing.m) {
                    // Calendar badge: weekday over day number.
                    VStack(spacing: 0) {
                        Text(next.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.selahLabelSmall.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.8)
                            .foregroundStyle(Tone.coral.ink)
                        Text(next.date.formatted(.dateTime.day()))
                            .font(.selahStat)
                            .foregroundStyle(.primary)
                    }
                    .frame(width: badgeSize, height: badgeSize)
                    .background(
                        Color(.systemBackground).opacity(0.7),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text(next.name)
                            .font(.selahCardTitle)
                            .foregroundStyle(.primary)
                        OnCardPill(text: timeText, icon: .clock, tone: tone)
                        Text(countdown)
                            .font(.selahLabel.weight(.semibold))
                            .foregroundStyle(tone.ink)
                    }
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(next.name), \(next.date.formatted(.dateTime.weekday(.wide).day().month(.wide))), \(timeText), \(countdown)")

                if next.isToday {
                    Button("Open service notes") {
                        openServiceNotes(named: next.name, now: now)
                    }
                    .buttonStyle(.selahPrimaryFull)
                } else {
                    Button("Go to services") { router.selectedTab = .services }
                        .buttonStyle(.selahSecondary(fullWidth: true))
                }
            }
        }
    }

    // MARK: Recent notes

    private var recentNotes: [RecentNote] {
        var items: [RecentNote] = []
        for entry in entries.prefix(6) {
            guard let plan = entry.plan else { continue }
            items.append(RecentNote(item: NoteItem(study: entry), target: .study(entry, plan)))
        }
        for service in services.prefix(6) {
            items.append(RecentNote(item: NoteItem(service: service), target: .service(service)))
        }
        for note in personalNotes.prefix(6) {
            items.append(RecentNote(item: NoteItem(personal: note), target: .personal(note)))
        }
        return Array(items.sorted { $0.item.date > $1.item.date }.prefix(3))
    }

    @ViewBuilder
    private var recentNotesSection: some View {
        let notes = recentNotes
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionTitle("Recent notes")
            if notes.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("Notes you write will show up here.")
                            .font(.selahLabel)
                            .foregroundStyle(.secondary)
                        Button("Write a note") {
                            router.selectedTab = .notes
                            // The Notes tab may not exist yet; hand the + action over once it does.
                            Task { @MainActor in
                                router.pendingAction = .newNote
                            }
                        }
                        .buttonStyle(.selahSecondary())
                    }
                }
            } else {
                VStack(spacing: Theme.Spacing.xs) {
                    ForEach(notes) { note in
                        Button {
                            open(note)
                        } label: {
                            NoteCard(
                                item: note.item,
                                wordCount: note.item.snippet.split(whereSeparator: { $0.isWhitespace }).count
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(note.item.listAccessibilityLabel)
                        .accessibilityHint("Opens this note")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
    }

    private func open(_ note: RecentNote) {
        switch note.target {
        case .study(let entry, let plan):
            cover = .entry(plan, entry)
        case .service(let service):
            cover = .service(service)
        case .personal(let personal):
            openNote = personal
        }
    }

    // MARK: Heatmap

    private func readingHeatmap(now: Date) -> some View {
        ActivityHeatmapCard(
            title: "Reading",
            subtitle: "Read a little, even on busy days",
            icon: .bookOpen,
            dates: entries.map { $0.date },
            year: $heatmapYear,
            unitSingular: "note",
            unitPlural: "notes",
            loggedToday: entries.contains { Calendar.current.isDate($0.date, inSameDayAs: now) },
            onLogToday: { router.pendingAction = .writeTodayEntry },
            today: now
        )
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.selahTitle)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    private func handlePendingAction() {
        guard router.pendingAction == .writeTodayEntry else { return }
        router.pendingAction = nil
        if let plan = readingPlans.first {
            cover = .entry(plan, entryToday(for: plan))
        } else {
            // No book yet: take the user to Study and open its add-a-book page.
            router.selectedTab = .study
            Task { @MainActor in
                router.pendingAction = .addBook
            }
        }
    }

    /// Creates or updates today's entry for the first Reading plan and gives it the chosen verse.
    private func setTodayVerse(_ verse: VerseRef) {
        let target: StudyEntry
        if let existing = verseEntryToday {
            target = existing
        } else if let plan = readingPlans.first {
            if let existing = entryToday(for: plan) {
                target = existing
            } else {
                let created = StudyEntry(date: Date(), chapter: StudyActions.nextChapter(in: plan))
                StudyActions.saveNewEntry(created, to: plan, markRead: false, in: modelContext)
                target = created
            }
        } else {
            return
        }
        if let old = target.bestVerse {
            modelContext.delete(old)
        }
        modelContext.insert(verse)
        target.bestVerse = verse
    }

    /// Opens today's service for this gathering, creating it if there is none yet.
    private func openServiceNotes(named name: String, now: Date) {
        let calendar = Calendar.current
        let existing = services.first {
            calendar.isDate($0.date, inSameDayAs: now) && $0.gatheringName == name
        }
        if let existing {
            cover = .service(existing)
        } else {
            let service = Service(date: now, gatheringName: name)
            modelContext.insert(service)
            cover = .service(service)
        }
    }
}

#Preview {
    TodayView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

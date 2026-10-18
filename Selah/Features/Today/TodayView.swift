import SwiftUI
import SwiftData

private enum TodaySheet: Identifiable {
    case entry(ReadingPlan, StudyEntry?)
    case verse
    case service(Service)

    var id: String {
        switch self {
        case .entry(let plan, _): return "entry-\(plan.persistentModelID.hashValue)"
        case .verse: return "verse"
        case .service(let service): return "service-\(service.persistentModelID.hashValue)"
        }
    }
}

private struct RecentNote: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let colour: NoteColour
    let systemImage: String
    let date: Date
}

struct TodayView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query private var profiles: [UserProfile]
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]
    @Query(sort: \StudyEntry.date, order: .reverse) private var entries: [StudyEntry]
    @Query(sort: \Service.date, order: .reverse) private var services: [Service]
    @Query(sort: \PersonalNote.updatedAt, order: .reverse) private var personalNotes: [PersonalNote]
    @Query private var meetingDays: [MeetingDay]

    @State private var sheet: TodaySheet?
    @State private var showSettings = false

    @ScaledMetric(relativeTo: .body) private var noteCardWidth: CGFloat = 152

    private var profile: UserProfile? { profiles.first }
    private var translation: Translation { profile?.translation ?? .kjv }
    private var textSize: Double { profile?.textSize ?? 17 }

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

    var body: some View {
        let now = Date()
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    header(now: now)
                    verseCard
                    readingSection(now: now)
                    gatheringSection(now: now)
                    recentNotesSection
                }
                .padding(.horizontal, Theme.Spacing.m)
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .background { AppBackground() }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        AvatarView(photoData: profile?.photoData, size: 32)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Profile and settings")
                }
            }
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $sheet) { item in
            switch item {
            case .entry(let plan, let entry):
                EntrySheet(plan: plan, entry: entry)
            case .verse:
                VersePicker(translation: translation) { setTodayVerse($0) }
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
            Text(now.formatted(.dateTime.weekday(.wide).day().month(.wide)).uppercased())
                .font(.system(.caption, design: .rounded, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(.secondary)
            Text(greeting)
                .font(.system(.title2, design: .rounded, weight: .semibold))
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: 1. Verse of the day (the one glass hero)

    @ViewBuilder
    private var verseCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("Verse of the day", systemImage: "quote.opening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                if let verse = verseEntryToday?.bestVerse {
                    ScaledVerseText(text: verse.textSnapshot, points: textSize)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(verse.reference) (\(verse.translation.shortName))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Button("Change verse") { sheet = .verse }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                } else if readingPlans.isEmpty && plans.isEmpty {
                    Text("Start a book in Study first")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Button("Go to Study") { router.selectedTab = .study }
                        .buttonStyle(.bordered)
                        .frame(minHeight: 44)
                } else {
                    Text("Pick a verse that spoke to you today.")
                        .font(.body)
                        .foregroundStyle(.primary)
                    Button("Choose today's verse") {
                        if readingPlans.isEmpty {
                            router.selectedTab = .study
                        } else {
                            sheet = .verse
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                }
            }
        }
    }

    // MARK: 2. Today's reading

    @ViewBuilder
    private func readingSection(now: Date) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle("Today's reading")
            if readingPlans.isEmpty {
                SurfaceCard {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("No book in progress")
                            .font(.headline)
                        Text("Start a book in Study and it will show up here each day.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Go to Study") { router.selectedTab = .study }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
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
        if let item = TodaySummary.readingItem(
            for: snapshot,
            hasEntryToday: existing != nil,
            now: now
        ) {
            SurfaceCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(item.bookName)
                            .font(.headline)
                        Text(item.nextText)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text("\(item.dayText) · \(item.paceText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let reminders = StudyActions.remindersText(for: plan) {
                            Text(reminders)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Button {
                        sheet = .entry(plan, existing)
                    } label: {
                        Text(item.hasEntryToday ? "Open today's entry" : "Write today's entry")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
    }

    // MARK: 3. Next gathering

    private func gatheringSection(now: Date) -> some View {
        let slots = meetingDays.map {
            MeetingSlot(name: $0.name, weekday: $0.weekday, hour: $0.hour, minute: $0.minute, isActive: $0.isActive)
        }
        let next = TodaySummary.nextGathering(from: slots, now: now)
        return VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle("Next gathering")
            SurfaceCard {
                if let next {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(next.name)
                                .font(.headline)
                            Text(next.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)

                        Button {
                            if next.isToday {
                                openServiceNotes(named: next.name, now: now)
                            } else {
                                router.selectedTab = .services
                            }
                        } label: {
                            Text(next.isToday ? "Open service notes" : "Go to services")
                                .frame(maxWidth: .infinity, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                } else {
                    VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                        Text("No meeting days yet")
                            .font(.headline)
                        Text("Add the days you meet in Settings and the next one will show here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Button("Open settings") { showSettings = true }
                            .buttonStyle(.bordered)
                            .frame(minHeight: 44)
                    }
                }
            }
        }
    }

    // MARK: 4. Recent notes

    private var recentNotes: [RecentNote] {
        var items: [RecentNote] = []
        for entry in entries.prefix(5) {
            let book = entry.plan?.bookName ?? "Study"
            items.append(RecentNote(
                id: "study-\(entry.persistentModelID.hashValue)",
                title: "\(book) \(entry.chapter)",
                subtitle: "Study · " + entry.date.formatted(date: .abbreviated, time: .omitted),
                colour: .mint,
                systemImage: "book",
                date: entry.date
            ))
        }
        for service in services.prefix(5) {
            let sermon = service.sermonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(RecentNote(
                id: "service-\(service.persistentModelID.hashValue)",
                title: sermon.isEmpty ? service.gatheringName : sermon,
                subtitle: "Services · " + service.date.formatted(date: .abbreviated, time: .omitted),
                colour: .sky,
                systemImage: "building.columns",
                date: service.date
            ))
        }
        for note in personalNotes.prefix(5) {
            let title = note.title.trimmingCharacters(in: .whitespacesAndNewlines)
            items.append(RecentNote(
                id: "personal-\(note.persistentModelID.hashValue)",
                title: title.isEmpty ? "Untitled note" : title,
                subtitle: "Personal · " + note.updatedAt.formatted(date: .abbreviated, time: .omitted),
                colour: note.colour,
                systemImage: "note.text",
                date: note.updatedAt
            ))
        }
        return Array(items.sorted { $0.date > $1.date }.prefix(5))
    }

    @ViewBuilder
    private var recentNotesSection: some View {
        let notes = recentNotes
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            sectionTitle("Recent notes")
            if notes.isEmpty {
                SurfaceCard {
                    Text("Notes you write will show up here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.Spacing.s) {
                        ForEach(notes) { note in
                            Button {
                                router.selectedTab = .notes
                            } label: {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Image(systemName: note.systemImage)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .accessibilityHidden(true)
                                    Text(note.title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(3)
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    Text(note.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(Theme.Spacing.s)
                                .frame(width: noteCardWidth, alignment: .leading)
                                .frame(minHeight: 112, alignment: .topLeading)
                                .background(
                                    note.colour.color,
                                    in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("\(note.title), \(note.subtitle)")
                            .accessibilityHint("Opens your notes")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }
                .scrollClipDisabled()
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Actions

    private func handlePendingAction() {
        guard router.pendingAction == .writeTodayEntry else { return }
        router.pendingAction = nil
        if let plan = readingPlans.first {
            sheet = .entry(plan, entryToday(for: plan))
        } else {
            // No book yet: take the user to Study and open its add-a-book sheet.
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
            sheet = .service(existing)
        } else {
            let service = Service(date: now, gatheringName: name)
            modelContext.insert(service)
            sheet = .service(service)
        }
    }
}

#Preview {
    TodayView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

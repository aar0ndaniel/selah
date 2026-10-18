import SwiftUI
import SwiftData

/// Modal wrapper around `EntryPage`, for callers that present a note as a sheet or full-screen cover
/// (Today, Notes). It supplies the `NavigationStack` the page needs for its toolbar and the verse picker.
///
/// Inside the Study tab the page is pushed instead (see `BookPage`), so it uses `EntryPage` directly.
struct EntrySheet: View {
    let plan: ReadingPlan
    let entry: StudyEntry?

    /// Pass nil for `entry` to write a new one (dated today).
    init(plan: ReadingPlan, entry: StudyEntry?) {
        self.plan = plan
        self.entry = entry
    }

    var body: some View {
        NavigationStack {
            EntryPage(plan: plan, entry: entry, presentation: .modal)
        }
        .presentationDetents([.large])
    }
}

/// Write or edit one daily study note as a full page. New notes are only created on Save; existing ones
/// edit in place.
///
/// - `.pushed`: sits in a navigation stack that is already there (the book page). A new note replaces the back
///   button with Cancel and Save; an existing note just has the back button.
/// - `.modal`: the root of a stack inside a sheet or cover. A new note has Cancel and Save, an existing one Done.
struct EntryPage: View {
    enum Presentation: Sendable {
        case pushed, modal
    }

    let plan: ReadingPlan
    let isNew: Bool
    let presentation: Presentation

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var entry: StudyEntry
    @State private var markRead: Bool
    @State private var showVersePicker = false
    @State private var saveCount = 0

    /// Pass nil for `entry` to write a new one. `date` is the day a new note is written for (default now).
    init(plan: ReadingPlan, entry: StudyEntry?, date: Date? = nil, presentation: Presentation = .pushed) {
        self.plan = plan
        self.isNew = entry == nil
        self.presentation = presentation
        let working = entry ?? StudyEntry(date: date ?? Date(), chapter: StudyActions.nextChapter(in: plan))
        _entry = State(initialValue: working)
        _markRead = State(initialValue: entry.map { plan.chaptersRead.contains($0.chapter) } ?? true)
    }

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    var body: some View {
        EntryFields(
            entry: entry,
            plan: plan,
            markRead: $markRead,
            showVersePicker: $showVersePicker,
            onRemoveVerse: { StudyActions.setBestVerse(nil, on: entry, in: modelContext) }
        )
        .background { AppBackground() }
        .navigationTitle(isNew ? "New note" : "Note")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isNew)
        .toolbar {
            if isNew {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            } else if presentation == .modal {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Pushed in the same stack rather than a second sheet on top.
        .navigationDestination(isPresented: $showVersePicker) {
            VersePicker(translation: translation, embedded: true) { verse in
                StudyActions.setBestVerse(verse, on: entry, in: modelContext)
            }
        }
        .modifier(PlusHiderWhenPushed(active: presentation == .pushed))
        .sensoryFeedback(.success, trigger: saveCount)
        .onChange(of: markRead) { _, newValue in
            // Existing notes apply the toggle straight away; new ones apply it on Save.
            if !isNew {
                StudyActions.applyReadToggle(newValue, chapter: entry.chapter, in: plan)
            }
        }
    }

    private func save() {
        StudyActions.saveNewEntry(entry, to: plan, markRead: markRead, in: modelContext)
        saveCount += 1
        dismiss()
    }
}

/// The floating + belongs to the tab's own screens; a pushed full page hides it.
private struct PlusHiderWhenPushed: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content.hidesPlusButton()
        } else {
            content
        }
    }
}

private struct EntryFields: View {
    @Bindable var entry: StudyEntry
    let plan: ReadingPlan
    @Binding var markRead: Bool
    @Binding var showVersePicker: Bool
    let onRemoveVerse: () -> Void

    @State private var showDatePicker = false

    private var tone: Tone { plan.cardTone }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                dateRow
                chapterCard
                verseCard
                noteCard
                markReadCard
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("Date", selection: $entry.date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, Theme.Spacing.m)
                    .navigationTitle("Choose a day")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showDatePicker = false }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Date

    /// Plain text with a calendar button, so a missed day can still be filled in.
    private var dateRow: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(plan.bookName)
                    .selahEyebrow()
                Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year()))
                    .font(.selahTitle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                showDatePicker = true
            } label: {
                PIconView(.calendarBlank, size: 24)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change date")
            .accessibilityHint("Pick another day for this note")
        }
    }

    // MARK: Chapter

    private var chapterCard: some View {
        SurfaceCard {
            HStack {
                Text("Chapter")
                    .font(.body)
                Spacer()
                Picker("Chapter", selection: $entry.chapter) {
                    ForEach(1...max(plan.totalChapters, 1), id: \.self) { chapter in
                        Text("Chapter \(chapter)").tag(chapter)
                    }
                }
                .pickerStyle(.menu)
                .frame(minHeight: Theme.minTapTarget)
            }
        }
    }

    // MARK: Best verse

    @ViewBuilder
    private var verseCard: some View {
        if let verse = entry.bestVerse {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Button {
                    showVersePicker = true
                } label: {
                    ToneCard(tone: tone) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            HStack {
                                Text("Best verse")
                                    .selahEyebrow()
                                    .foregroundStyle(tone.inkSecondary)
                                Spacer()
                                PIconView(.caretRight, size: 14, relativeTo: .footnote)
                                    .foregroundStyle(tone.inkSecondary)
                            }
                            Text(verse.textSnapshot)
                                .font(.selahVerseCompact)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Text(verse.reference)
                                .font(.selahHeadline)
                                .foregroundStyle(tone.ink)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Best verse, \(verse.reference). \(verse.textSnapshot)")
                .accessibilityHint("Opens the verse picker")

                Button("Remove verse", action: onRemoveVerse)
                    .buttonStyle(.selahTertiary)
            }
        } else {
            Button {
                showVersePicker = true
            } label: {
                Label("Choose a best verse", picon: .quotes)
            }
            .buttonStyle(.selahSecondary(tone: tone, fullWidth: true))
            .accessibilityHint("Opens the verse picker")
        }
    }

    // MARK: Note

    private var noteCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("What I learnt")
                    .font(.selahHeadline)
                    .accessibilityAddTraits(.isHeader)
                RichNoteEditor(
                    text: $entry.note,
                    owner: .study(entry),
                    field: .body,
                    placeholder: "What I learnt",
                    embedded: true
                )
            }
        }
    }

    // MARK: Mark read

    private var markReadCard: some View {
        SurfaceCard {
            Toggle("Mark chapter as read", isOn: $markRead)
                .frame(minHeight: Theme.minTapTarget)
        }
    }
}

#Preview("New note, pushed") {
    EntryPagePreview(existing: false, modal: false)
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

#Preview("Existing note, sheet") {
    EntryPagePreview(existing: true, modal: true)
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

private struct EntryPagePreview: View {
    let existing: Bool
    let modal: Bool
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            if modal {
                EntrySheet(plan: plan, entry: existing ? plan.entries.first : nil)
            } else {
                NavigationStack {
                    EntryPage(plan: plan, entry: existing ? plan.entries.first : nil)
                }
            }
        }
    }
}

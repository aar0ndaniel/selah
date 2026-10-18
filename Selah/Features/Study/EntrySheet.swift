import SwiftUI
import SwiftData

/// Write or edit one daily study entry. New entries are created on Save; existing ones edit in place.
struct EntrySheet: View {
    let plan: ReadingPlan
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    @State private var entry: StudyEntry
    @State private var markRead: Bool
    @State private var showVersePicker = false

    /// Pass nil for `entry` to write a new one.
    init(plan: ReadingPlan, entry: StudyEntry?) {
        self.plan = plan
        self.isNew = entry == nil
        let working = entry ?? StudyEntry(date: Date(), chapter: StudyActions.nextChapter(in: plan))
        _entry = State(initialValue: working)
        _markRead = State(initialValue: entry.map { plan.chaptersRead.contains($0.chapter) } ?? true)
    }

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    var body: some View {
        NavigationStack {
            EntryForm(
                entry: entry,
                plan: plan,
                markRead: $markRead,
                showVersePicker: $showVersePicker,
                onRemoveVerse: { StudyActions.setBestVerse(nil, on: entry, in: modelContext) }
            )
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle(isNew ? "New entry" : "Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isNew {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }
                    }
                } else {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showVersePicker) {
                VersePicker(translation: translation) { verse in
                    StudyActions.setBestVerse(verse, on: entry, in: modelContext)
                }
            }
            .onChange(of: markRead) { _, newValue in
                // Existing entries apply the toggle straight away; new ones apply it on Save.
                if !isNew {
                    StudyActions.applyReadToggle(newValue, chapter: entry.chapter, in: plan)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        StudyActions.saveNewEntry(entry, to: plan, markRead: markRead, in: modelContext)
        dismiss()
    }
}

private struct EntryForm: View {
    @Bindable var entry: StudyEntry
    let plan: ReadingPlan
    @Binding var markRead: Bool
    @Binding var showVersePicker: Bool
    let onRemoveVerse: () -> Void

    var body: some View {
        Form {
            Section {
                DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                Picker("Chapter", selection: $entry.chapter) {
                    ForEach(1...max(plan.totalChapters, 1), id: \.self) { chapter in
                        Text("Chapter \(chapter)").tag(chapter)
                    }
                }
            }

            Section("Best verse of the day") {
                Button {
                    showVersePicker = true
                } label: {
                    HStack {
                        if let verse = entry.bestVerse {
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(verse.reference)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(verse.textSnapshot)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        } else {
                            Text("Choose a verse")
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .accessibilityHint("Opens the verse picker")
                if entry.bestVerse != nil {
                    Button("Remove verse", role: .destructive, action: onRemoveVerse)
                }
            }

            Section("What I learnt") {
                RichNoteEditor(
                    text: $entry.note,
                    owner: .study(entry),
                    field: .body,
                    placeholder: "What I learnt"
                )
            }

            Section {
                Toggle("Mark chapter as read", isOn: $markRead)
            }
        }
    }
}

#Preview("New entry") {
    EntrySheetPreview(existing: false)
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

#Preview("Existing entry") {
    EntrySheetPreview(existing: true)
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

private struct EntrySheetPreview: View {
    let existing: Bool
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            EntrySheet(plan: plan, entry: existing ? plan.entries.first : nil)
        }
    }
}

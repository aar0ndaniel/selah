import SwiftUI
import SwiftData

/// Details for one book: plan, reminders, chapter grid, daily entries and delete.
struct BookSheet: View {
    @Bindable var plan: ReadingPlan
    /// Called when the reader confirms deleting. The parent deletes after this sheet is gone.
    let onDelete: (ReadingPlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .body) private var circleSize: CGFloat = 44

    @State private var newReminderTime = BookSheet.defaultReminderTime()
    @State private var showNewEntry = false
    @State private var editingEntry: StudyEntry?
    @State private var confirmDelete = false

    private static func defaultReminderTime() -> Date {
        Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var sortedReminders: [ReadingReminder] {
        plan.reminders.sorted { ($0.hour, $0.minute) < ($1.hour, $1.minute) }
    }

    private var sortedEntries: [StudyEntry] {
        plan.entries.sorted { $0.date > $1.date }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { plan.startDate ?? Date() },
            set: { plan.startDate = $0 }
        )
    }

    private var statusTitle: String {
        switch plan.status {
        case .reading: return "Reading"
        case .upNext: return "Up next"
        case .done: return "Done"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                planSection
                remindersSection
                chaptersSection
                entriesSection
                deleteSection
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle(plan.bookName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showNewEntry) {
                EntrySheet(plan: plan, entry: nil)
            }
            .sheet(item: $editingEntry) { entry in
                EntrySheet(plan: plan, entry: entry)
            }
            .confirmationDialog(
                "Delete \(plan.bookName)?",
                isPresented: $confirmDelete,
                titleVisibility: .visible
            ) {
                Button("Delete book", role: .destructive) {
                    onDelete(plan)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Its entries and reminders are deleted too.")
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Plan

    private var planSection: some View {
        Section {
            LabeledContent("Status", value: statusTitle)
            LabeledContent("Progress", value: StudyActions.progressText(for: plan))
            Stepper(value: $plan.plannedDays, in: 1...365) {
                Text("Planned days: \(plan.plannedDays)")
            }
            if plan.startDate != nil {
                DatePicker("Start date", selection: startDateBinding, displayedComponents: .date)
            } else {
                Button("Start reading today") {
                    StudyActions.startReading(plan)
                }
                .frame(minHeight: 44)
            }
            if plan.status == .reading {
                Text(StudyActions.planLine(for: plan))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Plan")
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            ForEach(sortedReminders) { reminder in
                Label(
                    StudyActions.timeText(hour: reminder.hour, minute: reminder.minute),
                    systemImage: "bell"
                )
                .frame(minHeight: 44, alignment: .leading)
            }
            .onDelete { offsets in
                let items = sortedReminders
                for index in offsets {
                    StudyActions.deleteReminder(items[index], in: modelContext)
                }
            }

            DatePicker("New reminder", selection: $newReminderTime, displayedComponents: .hourAndMinute)
            Button("Add reminder") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: newReminderTime)
                StudyActions.addReminder(
                    to: plan,
                    hour: parts.hour ?? 7,
                    minute: parts.minute ?? 0,
                    in: modelContext
                )
            }
            .frame(minHeight: 44)
        } header: {
            Text("Reminders")
        } footer: {
            if plan.reminders.isEmpty {
                Text("No reminders yet.")
            }
        }
    }

    // MARK: - Chapters

    private var chaptersSection: some View {
        Section {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? circleSize + 16 : circleSize), spacing: Theme.Spacing.xs)],
                spacing: Theme.Spacing.xs
            ) {
                ForEach(1...max(plan.totalChapters, 1), id: \.self) { chapter in
                    chapterCircle(chapter)
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
            .sensoryFeedback(.selection, trigger: plan.chaptersRead)
        } header: {
            Text("Chapters")
        } footer: {
            Text("Tap a chapter to mark it read or not read.")
        }
    }

    private func chapterCircle(_ chapter: Int) -> some View {
        let isRead = plan.chaptersRead.contains(chapter)
        return Button {
            StudyActions.toggleChapter(chapter, in: plan)
        } label: {
            VStack(spacing: 0) {
                if isRead {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                }
                Text("\(chapter)")
                    .font(.subheadline.weight(.semibold))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .foregroundStyle(isRead ? Color.white : Color.primary)
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

    // MARK: - Entries

    private var entriesSection: some View {
        Section {
            Button {
                showNewEntry = true
            } label: {
                Label("Write today's entry", systemImage: "square.and.pencil")
                    .frame(minHeight: 44, alignment: .leading)
            }

            ForEach(sortedEntries) { entry in
                Button {
                    editingEntry = entry
                } label: {
                    entryRow(entry)
                }
                .buttonStyle(.plain)
            }
            .onDelete { offsets in
                let items = sortedEntries
                for index in offsets {
                    modelContext.delete(items[index])
                }
            }
        } header: {
            Text("Daily entries")
        } footer: {
            if plan.entries.isEmpty {
                Text("No entries yet.")
            }
        }
    }

    private func entryRow(_ entry: StudyEntry) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Spacing.xxs))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Theme.Spacing.s))
        let dateText = entry.date.formatted(date: .abbreviated, time: .omitted)
        return layout {
            Text(dateText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Chapter \(entry.chapter)")
                    .font(.headline)
                if let verse = entry.bestVerse {
                    Text(verse.reference)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(dateText), chapter \(entry.chapter)" + (entry.bestVerse.map { ", best verse \($0.reference)" } ?? "")
        )
        .accessibilityHint("Opens the entry")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Delete

    private var deleteSection: some View {
        Section {
            Button("Delete book", role: .destructive) {
                confirmDelete = true
            }
            .frame(minHeight: 44)
        }
    }
}

private struct BookSheetPreview: View {
    @Query(sort: \ReadingPlan.bookName) private var plans: [ReadingPlan]

    var body: some View {
        if let plan = plans.first(where: { $0.status == .reading }) ?? plans.first {
            BookSheet(plan: plan) { _ in }
        }
    }
}

#Preview {
    BookSheetPreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

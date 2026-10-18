import SwiftUI
import SwiftData

/// Pick a book, a pace and a reminder, then start it today or put it in Up next.
struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var plans: [ReadingPlan]

    @State private var search = ""
    @State private var selectedBook: String?
    @State private var length: PlanLength = .fourteenDays
    @State private var remindMe = true
    @State private var reminderTime = AddBookSheet.defaultReminderTime()
    @State private var addedCount = 0

    /// Starts from the default reading time set in Settings.
    private static func defaultReminderTime() -> Date {
        ReminderDefaults.readingTime()
    }

    private var filteredBooks: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BibleBooks.names }
        let aliasMatch = BibleBooks.bookID(forAlias: query).flatMap { BibleBooks.name(for: $0) }
        return BibleBooks.names.filter {
            $0.localizedCaseInsensitiveContains(query) || $0 == aliasMatch
        }
    }

    private var duplicateMessage: String? {
        guard let book = selectedBook,
              let status = StudyActions.status(of: book, in: plans) else { return nil }
        let place = status == .reading ? "Reading" : "Up next"
        return "\(book) is already in \(place). Finish it or delete it first."
    }

    private var summary: String {
        guard let book = selectedBook, let index = BibleBooks.names.firstIndex(of: book) else {
            return "Choose a book below."
        }
        let chapters = BibleBooks.chapterCounts[index]
        let days = length.days(chapters: chapters)
        let perDay = max((chapters + days - 1) / days, 1)
        return "\(book): \(StudyActions.chaptersText(chapters)) in \(days) days, about \(StudyActions.chaptersText(perDay)) a day."
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    lengthPicker
                    Toggle("Daily reminder", isOn: $remindMe)
                    if remindMe {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } header: {
                    Text("Plan")
                } footer: {
                    Text(summary)
                }

                Section("Book") {
                    ForEach(filteredBooks, id: \.self) { book in
                        bookRow(book)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .searchable(text: $search, prompt: "Search books")
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { actionBar }
            .sensoryFeedback(.success, trigger: addedCount)
            .sensoryFeedback(.selection, trigger: selectedBook)
            .sensoryFeedback(.selection, trigger: length)
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var lengthPicker: some View {
        if typeSize.isAccessibilitySize {
            Picker("Length", selection: $length) { lengthOptions }
                .pickerStyle(.menu)
        } else {
            Picker("Length", selection: $length) { lengthOptions }
                .pickerStyle(.segmented)
                .labelsHidden()
        }
    }

    @ViewBuilder
    private var lengthOptions: some View {
        ForEach(PlanLength.allCases, id: \.self) { option in
            Text(option.title).tag(option)
        }
    }

    private func bookRow(_ book: String) -> some View {
        let isSelected = book == selectedBook
        let chapters = BibleBooks.chapterCounts[BibleBooks.names.firstIndex(of: book) ?? 0]
        return Button {
            selectedBook = book
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(book)
                        .foregroundStyle(.primary)
                    Text(StudyActions.chaptersText(chapters))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book), \(StudyActions.chaptersText(chapters))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var actionBar: some View {
        VStack(spacing: Theme.Spacing.xs) {
            if let message = duplicateMessage {
                // Red icon plus plain text: the warning is not colour alone, and the text keeps full contrast.
                Label {
                    Text(message)
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundStyle(.red)
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            GlassEffectContainer(spacing: Theme.Spacing.xs) {
                VStack(spacing: Theme.Spacing.xs) {
                    Button {
                        add(startNow: true)
                    } label: {
                        Text("Start today")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        add(startNow: false)
                    } label: {
                        Text("Add to Up next")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
        .disabled(selectedBook == nil || duplicateMessage != nil)
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
    }

    private func add(startNow: Bool) {
        guard let book = selectedBook else { return }
        var time: (hour: Int, minute: Int)?
        if remindMe {
            let parts = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            time = (parts.hour ?? 7, parts.minute ?? 0)
        }
        let plan = StudyActions.addPlan(
            bookName: book,
            length: length,
            startNow: startNow,
            reminderTime: time,
            in: modelContext
        )
        if plan != nil {
            addedCount += 1
            dismiss()
        }
    }
}

#Preview {
    AddBookSheet()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

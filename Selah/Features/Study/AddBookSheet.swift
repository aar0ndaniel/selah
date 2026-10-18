import SwiftUI
import SwiftData

/// Add a book: choose the book, how many days, start today or Up next, and an optional card colour.
/// Reminders are added later on the book page.
struct AddBookSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var plans: [ReadingPlan]

    @State private var selectedBook: String?
    @State private var days = 1
    @State private var startNow = true
    @State private var tone: NoteColour = .sage
    @State private var addedCount = 0

    private var chapters: Int? {
        guard let book = selectedBook, let index = BibleBooks.names.firstIndex(of: book) else { return nil }
        return BibleBooks.chapterCounts[index]
    }

    private var duplicateMessage: String? {
        guard let book = selectedBook,
              let status = StudyActions.status(of: book, in: plans) else { return nil }
        let place = status == .reading ? "Reading" : "Up next"
        return "\(book) is already in \(place). Finish it or delete it first."
    }

    private var canAdd: Bool { selectedBook != nil && duplicateMessage == nil }

    private var quickPicks: [DayQuickPicks.Pick] {
        [
            .init(id: "7", title: "7 days", days: 7),
            .init(id: "14", title: "14 days", days: 14),
            .init(id: "30", title: "30 days", days: 30),
            .init(id: "chapter", title: "1 chapter a day", days: chapters ?? 1, isEnabled: chapters != nil)
        ]
    }

    private var summary: String {
        guard let book = selectedBook, let chapters else { return "Choose a book first." }
        let perDay = max((chapters + days - 1) / days, 1)
        var text = "\(book): \(StudyActions.chaptersText(chapters)) in \(days) \(days == 1 ? "day" : "days")"
        if perDay > 1 { text += ", about \(perDay) a day" }
        return text + "."
    }

    var body: some View {
        NavigationStack {
            Form {
                bookSection
                daysSection
                startSection
                colourSection
            }
            .scrollContentBackground(.hidden)
            .background { AppBackground() }
            .navigationTitle("Add a book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { add() }
                        .disabled(!canAdd)
                }
            }
            .sensoryFeedback(.success, trigger: addedCount)
        }
        .presentationDetents([.large])
        .onChange(of: selectedBook) { _, _ in
            // "1 chapter a day" is the starting point: follow the book's chapter count until the reader picks
            // a different number of days.
            if followsChapters, let chapters { days = chapters }
        }
        .onChange(of: days) { _, newValue in
            // With no book yet, a number typed by the reader is kept when a book is chosen.
            followsChapters = chapters.map { $0 == newValue } ?? false
        }
    }

    /// True while the days equal the book's chapter count, or until the reader changes the days.
    @State private var followsChapters = true

    // MARK: Sections

    private var bookSection: some View {
        Section {
            NavigationLink {
                BookChooser(selection: $selectedBook)
            } label: {
                HStack {
                    Text("Book")
                    Spacer()
                    if let book = selectedBook {
                        Text(book)
                            .font(.selahHeadline)
                            .foregroundStyle(.primary)
                    } else {
                        Text("Choose")
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: Theme.minTapTarget)
            }
            .accessibilityHint("Opens the list of books")
        } footer: {
            if let message = duplicateMessage {
                // Red icon plus plain text: the warning is not colour alone, and the text keeps full contrast.
                Label {
                    Text(message)
                        .foregroundStyle(.primary)
                } icon: {
                    PIconView(.warningCircle, size: 16, relativeTo: .footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var daysSection: some View {
        Section {
            DaysStepperRow(days: $days)
            DayQuickPicks(picks: quickPicks, days: $days)
                .padding(.vertical, Theme.Spacing.xxs)
        } header: {
            Text("Days to finish")
        } footer: {
            Text(summary)
        }
    }

    private var startSection: some View {
        Section {
            Picker("Start", selection: $startNow) {
                Text("Start today").tag(true)
                Text("Up next").tag(false)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        } header: {
            Text("When")
        } footer: {
            Text(startNow ? "Day 1 is today." : "It waits in Up next until you start it.")
        }
    }

    private var colourSection: some View {
        Section {
            ToneSwatchPicker(selection: $tone)
                .padding(.vertical, Theme.Spacing.xxs)
        } header: {
            Text("Card colour")
        }
    }

    private func add() {
        guard let book = selectedBook else { return }
        let plan = StudyActions.addPlan(
            bookName: book,
            days: days,
            startNow: startNow,
            tone: tone,
            in: modelContext
        )
        if plan != nil {
            addedCount += 1
            dismiss()
        }
    }
}

/// Searchable list of the 66 books. Picking one goes back.
struct BookChooser: View {
    @Binding var selection: String?

    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filteredBooks: [String] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return BibleBooks.names }
        let aliasMatch = BibleBooks.bookID(forAlias: query).flatMap { BibleBooks.name(for: $0) }
        return BibleBooks.names.filter {
            $0.localizedCaseInsensitiveContains(query) || $0 == aliasMatch
        }
    }

    var body: some View {
        List {
            ForEach(filteredBooks, id: \.self) { book in
                row(book)
            }
        }
        .overlay {
            if filteredBooks.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
        .searchable(text: $search, prompt: "Search books")
        .bottomSearchToolbar()
        .navigationTitle("Choose a book")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ book: String) -> some View {
        let isSelected = book == selection
        let chapters = BibleBooks.chapterCounts[BibleBooks.names.firstIndex(of: book) ?? 0]
        return Button {
            selection = book
            dismiss()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(book)
                        .foregroundStyle(.primary)
                    Text(StudyActions.chaptersText(chapters))
                        .font(.selahLabelSmall)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected {
                    PIconView(.check, size: 20)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(book), \(StudyActions.chaptersText(chapters))")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    AddBookSheet()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

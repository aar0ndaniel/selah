import SwiftUI
import SwiftData

/// The Search tab (`Tab(role: .search)`). iOS 26 shows this tab as a round button beside the tab bar and moves the
/// `.searchable` field to the bottom of the screen, so the capsule never hides behind the tab bar.
///
/// Typing a Bible reference ("Phil 4:6") shows the verse text first, then any notes that match. Before typing:
/// recent notes and popular passages.
struct SearchHubView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var entries: [StudyEntry]
    @Query private var services: [Service]
    @Query private var personalNotes: [PersonalNote]
    @Query private var profiles: [UserProfile]

    @State private var query = ""
    @State private var openNote: PersonalNote?
    @State private var cover: SearchCover?

    private enum SearchCover: Identifiable {
        case study(StudyEntry, ReadingPlan)
        case service(Service)

        var id: String {
            switch self {
            case .study(let entry, _): return "study-\(entry.persistentModelID.hashValue)"
            case .service(let service): return "service-\(service.persistentModelID.hashValue)"
            }
        }
    }

    // MARK: Data

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    private var trimmed: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var allItems: [NoteItem] {
        entries.map { NoteItem(study: $0) }
            + services.map { NoteItem(service: $0) }
            + personalNotes.map { NoteItem(personal: $0) }
    }

    private var matchingNotes: [NoteItem] {
        NotesIndex.sorted(NotesIndex.filter(allItems, kind: nil, query: trimmed))
    }

    private var recentNotes: [NoteItem] {
        Array(NotesIndex.sorted(allItems).prefix(5))
    }

    private var reference: BibleReference? {
        trimmed.isEmpty ? nil : ReferenceParser().parse(trimmed)
    }

    private struct VerseResult {
        let reference: BibleReference
        let text: String
    }

    private var verseResult: VerseResult? {
        guard let reference else { return nil }
        let text = BibleStore.shared.text(for: reference, translation: translation)
        guard !text.isEmpty else { return nil }
        return VerseResult(reference: reference, text: text)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            Group {
                if trimmed.isEmpty {
                    startPage
                } else {
                    resultsPage
                }
            }
            .background { AppBackground() }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(item: $openNote) { note in
                PersonalNotePage(note: note, isNew: false)
            }
        }
        .searchable(text: $query, prompt: "Search notes, services and verses")
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .study(let entry, let plan):
                EntrySheet(plan: plan, entry: entry)
            case .service(let service):
                ServiceSheet(service: service)
            }
        }
    }

    // MARK: Before typing

    private var startPage: some View {
        List {
            if !recentNotes.isEmpty {
                Section {
                    ForEach(recentNotes) { noteRow($0) }
                } header: {
                    header("Recent notes")
                }
            }
            Section {
                ForEach(PopularPassages.all.prefix(5), id: \.self) { reference in
                    popularRow(reference)
                }
            } header: {
                header("Popular passages")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func popularRow(_ reference: BibleReference) -> some View {
        let text = BibleStore.shared.text(for: reference, translation: translation)
        return Button {
            query = reference.displayString
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(reference.displayString)
                    .font(.selahHeadline)
                    .foregroundStyle(.primary)
                if !text.isEmpty {
                    Text(text)
                        .font(.selahLabel)
                        .foregroundStyle(.primary.opacity(0.78))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reference.displayString). \(text)")
        .accessibilityHint("Searches for this passage")
        .rowStyle()
    }

    // MARK: Results

    @ViewBuilder
    private var resultsPage: some View {
        let verse = verseResult
        let notes = matchingNotes
        if verse == nil && notes.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else {
            List {
                if let verse {
                    Section {
                        verseRow(verse)
                    } header: {
                        header("Verses")
                    }
                }
                if !notes.isEmpty {
                    Section {
                        ForEach(notes) { noteRow($0) }
                    } header: {
                        header("Notes")
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func verseRow(_ verse: VerseResult) -> some View {
        let title = "\(verse.reference.displayString) (\(translation.shortName))"
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.selahHeadline)
            Text(verse.text)
                .font(.selahBody)
                .foregroundStyle(.primary.opacity(0.85))
                .lineLimit(verse.reference.verseStart == nil ? 8 : nil)
                .multilineTextAlignment(.leading)
            ShareLink(item: "\(verse.text)\n\(title)") {
                Label {
                    Text("Share")
                } icon: {
                    Image(picon: .shareNetwork)
                }
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
        .padding(Theme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .rowStyle()
    }

    private func noteRow(_ item: NoteItem) -> some View {
        let rich = richText(for: item)
        let words = rich?.wordCount ?? item.snippet.split(whereSeparator: { $0.isWhitespace }).count
        return Button {
            open(item)
        } label: {
            NoteCard(
                item: item,
                wordCount: words,
                highlightCount: rich?.highlightCount ?? 0,
                richSnippet: rich
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.listAccessibilityLabel)
        .accessibilityHint("Opens this note")
        .accessibilityAddTraits(.isButton)
        .rowStyle()
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.selahCardTitle)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.horizontal, Theme.Spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Opening notes (same destinations as the Notes tab)

    private func personalNote(for item: NoteItem) -> PersonalNote? {
        personalNotes.first { NoteItem.makeID(.personal, $0) == item.id }
    }

    private func richText(for item: NoteItem) -> AttributedString? {
        switch item.kind {
        case .personal:
            return personalNote(for: item)?.body
        case .study:
            return entries.first { NoteItem.makeID(.study, $0) == item.id }?.note
        case .service:
            return services.first { NoteItem.makeID(.service, $0) == item.id }?.previewNote
        }
    }

    private func open(_ item: NoteItem) {
        switch item.kind {
        case .study:
            if let entry = entries.first(where: { NoteItem.makeID(.study, $0) == item.id }),
               let plan = entry.plan {
                cover = .study(entry, plan)
            }
        case .service:
            if let service = services.first(where: { NoteItem.makeID(.service, $0) == item.id }) {
                cover = .service(service)
            }
        case .personal:
            if let note = personalNote(for: item) {
                openNote = note
            }
        }
    }
}

private extension View {
    /// Plain content rows on the page background, as in the Notes list.
    func rowStyle() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.m, bottom: 6, trailing: Theme.Spacing.m))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

#Preview("Search") {
    SearchHubView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

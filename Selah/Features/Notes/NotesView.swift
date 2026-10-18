import SwiftUI
import SwiftData

/// Every note in one place, as a list of note cards: pinned first by default, with kind chips and a sort menu.
///
/// Personal notes push a full page on this stack. Study and service notes open their own full-screen editors.
struct NotesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query private var entries: [StudyEntry]
    @Query private var services: [Service]
    @Query private var personalNotes: [PersonalNote]

    @State private var query = ""
    @State private var kind: NoteKind?
    @State private var sort: NoteSort = .pinnedFirst
    @State private var openNote: PersonalNote?
    @State private var freshNote: PersonalNote?
    @State private var cover: NotesCover?
    @State private var noteToDelete: PersonalNote?



    private enum NotesCover: Identifiable {
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

    private var allItems: [NoteItem] {
        entries.map { NoteItem(study: $0) }
            + services.map { NoteItem(service: $0) }
            + personalNotes.map { NoteItem(personal: $0) }
    }

    private var visibleItems: [NoteItem] {
        sort.apply(NotesIndex.filter(allItems, kind: kind, query: query))
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            listPage
            .background { AppBackground() }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.pendingAction = .newNote
                    } label: {
                        Label {
                            Text("New note")
                        } icon: {
                            Image(picon: .plus)
                        }
                    }
                    .accessibilityLabel("New note")
                    .accessibilityIdentifier("plus-button")
                }
            }
            .sensoryFeedback(.selection, trigger: sort)
            .navigationDestination(item: $openNote) { note in
                PersonalNotePage(note: note, isNew: note === freshNote)
            }
        }
        .fullScreenCover(item: $cover) { cover in
            switch cover {
            case .study(let entry, let plan):
                EntrySheet(plan: plan, entry: entry)
            case .service(let service):
                ServiceSheet(service: service)
            }
        }
        .confirmationDialog(
            "Delete this note?",
            isPresented: Binding(
                get: { noteToDelete != nil },
                set: { if !$0 { noteToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: noteToDelete
        ) { note in
            Button("Delete note", role: .destructive) { delete(note) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("This also removes its verses and comments.")
        }
        .onChange(of: openNote) { old, new in
            // The page closed. A new note with nothing written is not kept.
            if new == nil, let old, old.isBlank {
                modelContext.delete(old)
                try? modelContext.save()
            }
            if new == nil { freshNote = nil }
        }
        .onChange(of: router.pendingAction) { _, _ in handlePendingAction() }
        .onAppear { handlePendingAction() }
    }

    private var chips: some View {
        FilterChips(items: [NoteKind?.none] + NoteKind.allCases.map { Optional($0) }, selection: $kind) {
            $0?.chipTitle ?? "All"
        }
    }

    private var listPage: some View {
        let items = visibleItems
        return List {
            headerRow(count: items.count)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.m, bottom: 0, trailing: Theme.Spacing.m))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            chips
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if items.isEmpty {
                emptyState
                    .padding(.top, Theme.Spacing.xl)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(items) { listRow(for: $0) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
    }

    /// "12 notes" in the accent colour, and a sort menu on the right.
    private func headerRow(count: Int) -> some View {
        HStack {
            Text(count == 1 ? "1 note" : "\(count) notes")
                .font(.selahLabel)
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("notes-count")
            Spacer(minLength: Theme.Spacing.s)
            Menu {
                Picker("Sort notes", selection: $sort) {
                    ForEach(NoteSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                Image(picon: .funnelSimple)
                    .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Sort notes")
            .accessibilityValue(sort.title)
            .accessibilityIdentifier("notes-sort")
        }
    }
    @ViewBuilder
    private var emptyState: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else if kind != nil {
            EmptyState(
                title: "No notes here yet",
                icon: .note,
                message: "Try another filter, or write a note of your own.",
                actionTitle: "New note",
                action: { createNote() }
            )
        } else {
            EmptyState(
                title: "No notes yet",
                icon: .note,
                message: "Study entries, service notes and your own notes show up here.",
                actionTitle: "New note",
                action: { createNote() }
            )
        }
    }

    // MARK: List


    private func listRow(for item: NoteItem) -> some View {
        let rich = richText(for: item)
        let personal = item.kind == .personal ? personalNote(for: item) : nil
        let words = rich?.wordCount ?? item.snippet.split(whereSeparator: { $0.isWhitespace }).count
        return tappable(item, accessibilityLabel: item.listAccessibilityLabel) {
            NoteCard(
                item: item,
                wordCount: words,
                highlightCount: rich?.highlightCount ?? 0,
                richSnippet: rich
            )
        }
        .listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.m, bottom: 6, trailing: Theme.Spacing.m))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if let personal {
                Button(role: .destructive) {
                    noteToDelete = personal
                } label: {
                    Label("Delete", picon: .trash)
                }
                Button {
                    togglePin(personal)
                } label: {
                    Label(personal.pinned ? "Unpin" : "Pin", picon: personal.pinned ? .pushPinSlash : .pushPin)
                }
                .tint(Color(.systemGray))
            }
        }
    }

    // MARK: Shared row behaviour

    /// Wraps a note's visual in a button with one combined accessibility element and, for personal notes,
    /// a context menu with the same pin and delete actions that the list swipe offers.
    @ViewBuilder
    private func tappable<Visual: View>(
        _ item: NoteItem,
        accessibilityLabel: String,
        @ViewBuilder content: () -> Visual
    ) -> some View {
        let personal = item.kind == .personal ? personalNote(for: item) : nil
        let button = Button {
            open(item)
        } label: {
            content()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens this note")
        .accessibilityAddTraits(.isButton)

        if let personal {
            button
                .contextMenu {
                    Button {
                        togglePin(personal)
                    } label: {
                        Label(personal.pinned ? "Unpin" : "Pin", picon: personal.pinned ? .pushPinSlash : .pushPin)
                    }
                    Button(role: .destructive) {
                        noteToDelete = personal
                    } label: {
                        Label("Delete", picon: .trash)
                    }
                }
                .accessibilityAction(named: personal.pinned ? "Unpin" : "Pin") { togglePin(personal) }
                .accessibilityAction(named: "Delete") { noteToDelete = personal }
        } else {
            button
        }
    }

    // MARK: Actions

    private func personalNote(for item: NoteItem) -> PersonalNote? {
        personalNotes.first { NoteItem.makeID(.personal, $0) == item.id }
    }

    /// The note's rich text, so highlights show on the card. Only looked up for cards that are on screen.
    private func richText(for item: NoteItem) -> AttributedString? {
        switch item.kind {
        case .personal:
            return personalNote(for: item)?.body
        case .study:
            return entries.first { NoteItem.makeID(.study, $0) == item.id }?.note
        case .service:
            return services.first { NoteItem.makeID(.service, $0) == item.id }?.sermonNote
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

    /// Adds a new empty note to the store and opens its page straight away.
    private func createNote() {
        let note = PersonalNote()
        modelContext.insert(note)
        freshNote = note
        openNote = note
    }

    private func togglePin(_ note: PersonalNote) {
        note.pinned.toggle()
        note.updatedAt = Date()
        try? modelContext.save()
    }

    private func delete(_ note: PersonalNote) {
        modelContext.delete(note)
        try? modelContext.save()
        noteToDelete = nil
    }

    private func handlePendingAction() {
        guard router.pendingAction == .newNote else { return }
        router.pendingAction = nil
        createNote()
    }
}


#Preview {
    NotesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

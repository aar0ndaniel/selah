import SwiftUI
import SwiftData

/// Every note in one place, as a board of sticky notes on the plain page: a pinned row on top, then a
/// two-column grid (one column at accessibility text sizes).
///
/// Personal notes push a full page on this stack. Study and service notes open their own full-screen editors.
struct NotesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize

    @Query private var entries: [StudyEntry]
    @Query private var services: [Service]
    @Query private var personalNotes: [PersonalNote]

    @State private var query = ""
    @State private var kind: NoteKind?
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

    private var visibleSections: (pinned: [NoteItem], others: [NoteItem]) {
        NotesIndex.sections(NotesIndex.filter(allItems, kind: kind, query: query))
    }

    private var columnCount: Int { typeSize.isAccessibilitySize ? 1 : 2 }

    // MARK: Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    FilterChips(items: [NoteKind?.none] + NoteKind.allCases.map { Optional($0) }, selection: $kind) {
                        $0?.chipTitle ?? "All"
                    }
                    content
                }
            }
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .background { AppBackground() }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search notes and verses")
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

    @ViewBuilder
    private var content: some View {
        let sections = visibleSections
        if sections.pinned.isEmpty && sections.others.isEmpty {
            emptyState
                .padding(.top, Theme.Spacing.xl)
        } else {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                if !sections.pinned.isEmpty {
                    pinnedRow(sections.pinned)
                }
                if !sections.others.isEmpty {
                    board(title: sections.pinned.isEmpty ? nil : "Other notes", items: sections.others)
                }
            }
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

    // MARK: Board

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.selahCardTitle)
            .padding(.horizontal, Theme.Spacing.m)
            .accessibilityAddTraits(.isHeader)
    }

    /// Pinned notes: a horizontal row of larger notes.
    private func pinnedRow(_ items: [NoteItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            sectionHeader("Pinned")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: Theme.Spacing.m) {
                    ForEach(items) { item in
                        card(for: item, size: .large)
                    }
                }
                .padding(.horizontal, Theme.Spacing.m)
                // Room for the soft shadow and the tilt, which the scroll view would otherwise clip.
                .padding(.vertical, Theme.Spacing.s)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// The rest: masonry-like columns, each new note going to the shortest column.
    private func board(title: String?, items: [NoteItem]) -> some View {
        let columns = StickyStyle.split(
            heights: items.map { StickyStyle.estimatedHeight(for: $0) },
            columns: columnCount
        )
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let title {
                sectionHeader(title)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                ForEach(columns.indices, id: \.self) { column in
                    LazyVStack(spacing: Theme.Spacing.m) {
                        ForEach(columns[column], id: \.self) { index in
                            card(for: items[index])
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.xs)
        }
    }

    @ViewBuilder
    private func card(for item: NoteItem, size: StickyNoteCard.Size = .regular) -> some View {
        let personal = item.kind == .personal ? personalNote(for: item) : nil
        let button = Button {
            open(item)
        } label: {
            StickyNoteCard(item: item, size: size, richSnippet: richText(for: item))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.stickyAccessibilityLabel)
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

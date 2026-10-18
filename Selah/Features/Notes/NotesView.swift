import SwiftUI
import SwiftData

/// Every note in one place. Board (default): a collage of tilted notes held up by pins, tape and clips on the plain
/// page, a pinned row on top, then two staggered columns (one at accessibility text sizes). List: rounded rows.
/// A toolbar button switches between them and the choice is remembered.
///
/// Personal notes push a full page on this stack. Study and service notes open their own full-screen editors.
struct NotesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize

    @Query private var entries: [StudyEntry]
    @Query private var services: [Service]
    @Query private var personalNotes: [PersonalNote]

    @AppStorage("notesLayout") private var layoutRaw = NotesLayout.board.rawValue
    @State private var query = ""
    @State private var kind: NoteKind?
    @State private var openNote: PersonalNote?
    @State private var freshNote: PersonalNote?
    @State private var cover: NotesCover?
    @State private var noteToDelete: PersonalNote?

    enum NotesLayout: String {
        case board, list
    }

    private var layout: NotesLayout { NotesLayout(rawValue: layoutRaw) ?? .board }

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
            Group {
                switch layout {
                case .board: boardPage
                case .list: listPage
                }
            }
            .background { AppBackground() }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $query, prompt: "Search notes and verses")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        layoutRaw = (layout == .board ? NotesLayout.list : NotesLayout.board).rawValue
                    } label: {
                        Label {
                            Text(layout == .board ? "List" : "Board")
                        } icon: {
                            Image(layout == .board ? "ph-list" : "ph-squares-four")
                        }
                    }
                    .accessibilityLabel(layout == .board ? "Show as list" : "Show as board")
                }
            }
            .sensoryFeedback(.selection, trigger: layoutRaw)
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

    private var isEmpty: Bool {
        let sections = visibleSections
        return sections.pinned.isEmpty && sections.others.isEmpty
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

    private var boardPage: some View {
        let sections = visibleSections
        return ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                chips
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
        }
        .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
    }

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
                LazyHStack(alignment: .top, spacing: Theme.Spacing.l) {
                    ForEach(items) { item in
                        boardCard(for: item, size: .large)
                    }
                }
                .padding(.horizontal, Theme.Spacing.l)
                // Room above for the pins and tape, and around for the shadow and the tilt, which the scroll view
                // would otherwise clip.
                .padding(.top, Theme.Spacing.l)
                .padding(.bottom, Theme.Spacing.m)
            }
            .scrollIndicators(.hidden)
        }
    }

    /// How far the second column is pushed down, for the staggered look.
    private static let stagger: Double = 28

    /// The rest: two staggered columns, each new note going to the shortest column. Notes overlap a little at the
    /// edges (their padding absorbs it), and the room above each note holds its pin, tape or clip.
    private func board(title: String?, items: [NoteItem]) -> some View {
        let heights = items.map { StickyStyle.estimatedHeight(for: $0) }
        let columns = StickyStyle.split(heights: heights, columns: columnCount)
        let offsets: [Double] = columns.indices.map { $0 % 2 == 1 ? Self.stagger : 0 }
        // VoiceOver reads top to bottom, as the board looks, not column by column.
        let order = StickyStyle.readingOrder(columns: columns, heights: heights, columnOffsets: offsets)
        var priority: [Int: Double] = [:]
        for (rank, index) in order.enumerated() {
            priority[index] = Double(order.count - rank)
        }
        return VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if let title {
                sectionHeader(title)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                ForEach(columns.indices, id: \.self) { column in
                    LazyVStack(spacing: Theme.Spacing.xs) {
                        ForEach(columns[column], id: \.self) { index in
                            boardCard(for: items[index])
                                .zIndex(Double(index))
                                .accessibilitySortPriority(priority[index] ?? 0)
                        }
                    }
                    .padding(.top, CGFloat(offsets[column]) + Theme.Spacing.m)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
            }
            .accessibilityElement(children: .contain)
            .padding(.horizontal, Theme.Spacing.m + 4)
            .padding(.bottom, Theme.Spacing.xs)
        }
    }

    private func boardCard(for item: NoteItem, size: BoardNoteCard.Size = .regular) -> some View {
        tappable(item, accessibilityLabel: item.stickyAccessibilityLabel) {
            BoardNoteCard(item: item, size: size, richSnippet: richText(for: item))
        }
    }

    // MARK: List

    private var listPage: some View {
        let sections = visibleSections
        return List {
            chips
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if sections.pinned.isEmpty && sections.others.isEmpty {
                emptyState
                    .padding(.top, Theme.Spacing.xl)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                if !sections.pinned.isEmpty {
                    Section {
                        ForEach(sections.pinned) { listRow(for: $0) }
                    } header: {
                        listHeader("Pinned")
                    }
                }
                if !sections.others.isEmpty {
                    Section {
                        ForEach(sections.others) { listRow(for: $0) }
                    } header: {
                        listHeader(sections.pinned.isEmpty ? "All notes" : "Other notes")
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
    }

    private func listHeader(_ title: String) -> some View {
        Text(title)
            .font(.selahCardTitle)
            .foregroundStyle(.primary)
            .textCase(nil)
            .padding(.horizontal, Theme.Spacing.xxs)
            .accessibilityAddTraits(.isHeader)
    }

    private func listRow(for item: NoteItem) -> some View {
        let rich = richText(for: item)
        let personal = item.kind == .personal ? personalNote(for: item) : nil
        let words = rich?.wordCount ?? item.snippet.split(whereSeparator: { $0.isWhitespace }).count
        return tappable(item, accessibilityLabel: item.listAccessibilityLabel) {
            NoteListRow(
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

#Preview("Board") {
    NotesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

#Preview("List") {
    UserDefaults.standard.set("list", forKey: "notesLayout")
    return NotesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

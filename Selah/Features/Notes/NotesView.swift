import SwiftUI
import SwiftData

/// Every note in one place: study notes, service notes and personal notes, as a grid of sticky cards.
struct NotesView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize

    @Query private var entries: [StudyEntry]
    @Query private var services: [Service]
    @Query private var personalNotes: [PersonalNote]

    @State private var query = ""
    @State private var kind: NoteKind?
    @State private var destination: NoteDestination?
    @State private var noteToDelete: PersonalNote?

    private enum NoteDestination: Identifiable {
        case study(StudyEntry, ReadingPlan)
        case service(Service)
        case personal(PersonalNote)
        case newPersonal

        var id: String {
            switch self {
            case .study(let entry, _): return "study-\(entry.persistentModelID.hashValue)"
            case .service(let service): return "service-\(service.persistentModelID.hashValue)"
            case .personal(let note): return "personal-\(note.persistentModelID.hashValue)"
            case .newPersonal: return "new-personal"
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

    private var columns: [GridItem] {
        let count = typeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s, alignment: .top), count: count)
    }

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
        }
        .sheet(item: $destination) { destination in
            sheet(for: destination)
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
                    grid(title: "Pinned", items: sections.pinned)
                }
                if !sections.others.isEmpty {
                    grid(title: sections.pinned.isEmpty ? nil : "Other notes", items: sections.others)
                }
            }
            .padding(.horizontal, Theme.Spacing.m)
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
                action: { destination = .newPersonal }
            )
        } else {
            EmptyState(
                title: "No notes yet",
                icon: .note,
                message: "Study entries, service notes and your own notes show up here.",
                actionTitle: "New note",
                action: { destination = .newPersonal }
            )
        }
    }

    private func grid(title: String?, items: [NoteItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let title {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .accessibilityAddTraits(.isHeader)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(items) { item in
                    card(for: item)
                }
            }
        }
    }

    @ViewBuilder
    private func card(for item: NoteItem) -> some View {
        let personal = item.kind == .personal ? personalNote(for: item) : nil
        let button = Button {
            open(item)
        } label: {
            StickyNoteCard(item: item)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.accessibilityDescription)
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

    // MARK: Sheets

    @ViewBuilder
    private func sheet(for destination: NoteDestination) -> some View {
        switch destination {
        case .study(let entry, let plan):
            EntrySheet(plan: plan, entry: entry)
        case .service(let service):
            ServiceSheet(service: service)
        case .personal(let note):
            PersonalNoteSheet(note: note)
        case .newPersonal:
            PersonalNoteSheet(note: nil)
        }
    }

    // MARK: Actions

    private func personalNote(for item: NoteItem) -> PersonalNote? {
        personalNotes.first { NoteItem.makeID(.personal, $0) == item.id }
    }

    private func open(_ item: NoteItem) {
        switch item.kind {
        case .study:
            if let entry = entries.first(where: { NoteItem.makeID(.study, $0) == item.id }),
               let plan = entry.plan {
                destination = .study(entry, plan)
            }
        case .service:
            if let service = services.first(where: { NoteItem.makeID(.service, $0) == item.id }) {
                destination = .service(service)
            }
        case .personal:
            if let note = personalNote(for: item) {
                destination = .personal(note)
            }
        }
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
        destination = .newPersonal
    }
}

// MARK: - Sticky card

/// One sticky note. It is content, so it gets a flat colour fill and no glass.
private struct StickyNoteCard: View {
    let item: NoteItem

    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 144

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xxs) {
                PLabel(item.kind.label, icon: item.kind.icon, size: 12, textStyle: .caption)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .labelStyle(.titleAndIcon)
                Spacer(minLength: 0)
                if item.pinned {
                    PIconView(.pushPin, filled: true, size: 12, relativeTo: .caption)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.displayTitle)
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
            if !item.snippet.isEmpty {
                Text(item.snippet)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
            }
            Spacer(minLength: 0)
            Text(item.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .background(item.colour.color, in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
    }
}

// MARK: - Display helpers

extension NoteKind {
    var label: String {
        switch self {
        case .study: return "Study"
        case .service: return "Service"
        case .personal: return "Personal"
        }
    }

    var chipTitle: String {
        switch self {
        case .study: return "Study"
        case .service: return "Services"
        case .personal: return "Personal"
        }
    }

    var icon: PIcon {
        switch self {
        case .study: return .bookOpen
        case .service: return .church
        case .personal: return .userCircle
        }
    }
}

extension NoteItem {
    var displayTitle: String {
        title.isEmpty ? "Untitled note" : title
    }

    var accessibilityDescription: String {
        var parts = ["\(kind.label) note", displayTitle]
        if !snippet.isEmpty { parts.append(snippet) }
        parts.append(date.formatted(.dateTime.day().month(.wide).year()))
        if pinned { parts.append("Pinned") }
        return parts.joined(separator: ". ")
    }
}

#Preview {
    NotesView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

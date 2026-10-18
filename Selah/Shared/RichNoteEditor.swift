import SwiftData
import SwiftUI

extension Theme.Palette {
    /// Soft mint behind highlighted words. Pale in light mode, deep muted green-teal in dark mode.
    static let highlightMint = Color("HighlightMint")
}

/// Note text with highlight and comment.
///
/// Select words, tap Highlight, write a comment. The words get a soft mint background and the comment
/// shows under the note. Tap highlighted words to jump to their comment. Deleting a comment removes its
/// highlight; deleting the highlighted words removes its comment.
///
/// Built on a UITextView wrapper (`HighlightTextView`) rather than the iOS 26 `TextEditor` with
/// `AttributedTextSelection`: selection, typing attributes and tap detection are all certain there.
/// Only words and highlights are kept; other formatting is not supported by this editor.
struct RichNoteEditor: View {
    @Binding private var text: AttributedString
    private let owner: NoteOwner
    private let field: CommentField
    private let placeholder: String
    /// True when the editor sits inside a Form or List row that already draws a card:
    /// no second card and no extra padding, so it does not look like a card in a card.
    private let embedded: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var minEditorHeight: CGFloat = 120

    @State private var pending: PendingHighlight?
    @State private var unresolvedID: String?
    @State private var emphasizedID: String?
    @State private var revealRequest: RevealRequest?
    @State private var emphasisTask: Task<Void, Never>?

    init(
        text: Binding<AttributedString>,
        owner: NoteOwner,
        field: CommentField,
        placeholder: String = "Write your note",
        embedded: Bool = false
    ) {
        self._text = text
        self.owner = owner
        self.field = field
        self.placeholder = placeholder
        self.embedded = embedded
    }

    var body: some View {
        ScrollViewReader { proxy in
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                editorField(proxy: proxy)
                if !comments.isEmpty {
                    commentsSection
                }
            }
        }
        .sheet(item: $pending, onDismiss: discardUnresolvedHighlight) { item in
            HighlightCommentSheet(
                quote: item.quote,
                onSave: { comment in save(comment, for: item) },
                onCancel: { pending = nil }
            )
        }
    }

    // MARK: Editor

    private func editorField(proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .topLeading) {
            HighlightTextView(
                text: $text,
                placeholder: placeholder,
                minHeight: minEditorHeight,
                reveal: revealRequest,
                onEdit: { newText in removeOrphanedComments(in: newText) },
                onHighlight: { id, quote in
                    unresolvedID = id
                    pending = PendingHighlight(id: id, quote: quote)
                },
                onHighlightTap: { id in jumpToComment(id, proxy: proxy) }
            )
            if text.characters.isEmpty {
                Text(placeholder)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .padding(embedded ? 0 : Theme.Spacing.s)
        .background {
            if !embedded {
                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            }
        }
    }

    // MARK: Comments

    private var comments: [NoteComment] {
        let all: [NoteComment]
        switch owner {
        case .study(let entry): all = entry.comments
        case .service(let service): all = service.comments
        case .personal(let note): all = note.comments
        }
        let order = HighlightLogic.orderedIDs(in: text)
        func position(_ comment: NoteComment) -> Int {
            order.firstIndex(of: comment.highlightID) ?? Int.max
        }
        return all
            .filter { $0.field == field }
            .sorted {
                let left = position($0)
                let right = position($1)
                return left == right ? $0.createdAt < $1.createdAt : left < right
            }
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Comments")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(comments, id: \.highlightID) { comment in
                CommentRow(
                    comment: comment,
                    isEmphasized: emphasizedID == comment.highlightID,
                    reduceMotion: reduceMotion,
                    baseColor: embedded ? Color(.tertiarySystemGroupedBackground) : Color(.secondarySystemGroupedBackground),
                    onShow: { revealRequest = RevealRequest(id: comment.highlightID) },
                    onDelete: { delete(comment) }
                )
                .id(comment.highlightID)
            }
        }
    }

    // MARK: Actions

    private func save(_ commentText: String, for item: PendingHighlight) {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        let comment = NoteComment(
            highlightID: item.id,
            quotedText: item.quote,
            comment: trimmed,
            field: field
        )
        modelContext.insert(comment)
        switch owner {
        case .study(let entry): comment.studyEntry = entry
        case .service(let service): comment.service = service
        case .personal(let note): comment.personalNote = note
        }
        try? modelContext.save()
        unresolvedID = nil
        pending = nil
    }

    /// Runs when the comment sheet goes away. Without a saved comment, the new highlight is taken back.
    private func discardUnresolvedHighlight() {
        guard let id = unresolvedID else { return }
        unresolvedID = nil
        var updated = text
        HighlightLogic.removeHighlight(id: id, from: &updated)
        text = updated
    }

    private func delete(_ comment: NoteComment) {
        var updated = text
        HighlightLogic.removeHighlight(id: comment.highlightID, from: &updated)
        text = updated
        modelContext.delete(comment)
        try? modelContext.save()
    }

    /// The user typed or deleted words. Comments whose highlighted words are gone are deleted too.
    private func removeOrphanedComments(in newText: AttributedString) {
        let current = comments
        let orphaned = HighlightLogic.orphanedIDs(commentIDs: current.map(\.highlightID), in: newText)
        guard !orphaned.isEmpty else { return }
        for comment in current where orphaned.contains(comment.highlightID) {
            modelContext.delete(comment)
        }
        try? modelContext.save()
    }

    private func jumpToComment(_ id: String, proxy: ScrollViewProxy) {
        guard comments.contains(where: { $0.highlightID == id }) else { return }
        withAnimation(reduceMotion ? nil : .smooth) {
            proxy.scrollTo(id, anchor: .center)
        }
        emphasizedID = id
        emphasisTask?.cancel()
        emphasisTask = Task {
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            emphasizedID = nil
        }
    }
}

// MARK: - Pending highlight

private struct PendingHighlight: Identifiable {
    let id: String
    let quote: String
}

// MARK: - Comment row

private struct CommentRow: View {
    let comment: NoteComment
    let isEmphasized: Bool
    let reduceMotion: Bool
    let baseColor: Color
    let onShow: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.s) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(Theme.Palette.highlightMint)
                .frame(width: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(comment.quotedText)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
                Text(comment.comment)
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                actions
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityHidden(true)
        }
        .padding(.leading, Theme.Spacing.s)
        .padding(.vertical, Theme.Spacing.xs)
        .background(
            isEmphasized ? Theme.Palette.highlightMint : baseColor,
            in: RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                .stroke(Color.accentColor, lineWidth: isEmphasized ? 2 : 0)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isEmphasized)
        .contextMenu { actions }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Highlight: \(comment.quotedText). Comment: \(comment.comment)")
        .accessibilityAction(named: "Show in note", onShow)
        .accessibilityAction(named: "Delete comment", onDelete)
    }

    @ViewBuilder
    private var actions: some View {
        Button(action: onShow) {
            Label("Show in note", systemImage: "text.cursor")
        }
        Button(role: .destructive, action: onDelete) {
            Label("Delete comment", systemImage: "trash")
        }
    }
}

// MARK: - Comment sheet

private struct HighlightCommentSheet: View {
    let quote: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var comment = ""
    @FocusState private var focused: Bool

    private var canSave: Bool {
        !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Highlighted words") {
                    Text(quote)
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                }
                Section("Your comment") {
                    TextField("Add a comment", text: $comment, axis: .vertical)
                        .lineLimit(3...8)
                        .focused($focused)
                        .frame(minHeight: 44, alignment: .topLeading)
                }
            }
            .navigationTitle("Add a comment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(comment) }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { focused = true }
    }
}

// MARK: - Preview

#Preview("Study entry") {
    RichNoteEditorPreview()
        .modelContainer(SampleData.container)
}

private struct RichNoteEditorPreview: View {
    @Query(sort: \StudyEntry.date) private var entries: [StudyEntry]

    var body: some View {
        if let entry = entries.first {
            RichNoteEditorPreviewBody(entry: entry)
        } else {
            Text("No sample entry")
        }
    }
}

private struct RichNoteEditorPreviewBody: View {
    @Bindable var entry: StudyEntry

    var body: some View {
        ScrollView {
            RichNoteEditor(text: $entry.note, owner: .study(entry), field: .body)
                .padding(Theme.Spacing.m)
        }
        .background(Color(.systemGroupedBackground))
    }
}

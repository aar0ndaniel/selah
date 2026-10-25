import SwiftUI
import SwiftData

/// One verse box in the editor.
private struct SongEditorVerse: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

/// What the editor is changing, kept apart from the model until Save.
private struct SongEditorDraft {
    var type: SongType = .hymn
    var title = ""
    var hymnNumber = ""
    var verses: [SongEditorVerse] = [SongEditorVerse(text: "")]
    var refrain = ""
    var externalID: String?
    /// True when the verses came from Hymnary in this editing session.
    var importedLyrics = false

    init() {}

    init(_ song: LibrarySong) {
        type = song.songType
        title = song.title
        hymnNumber = song.hymnNumber
        let existing = song.lyricVerses.map { SongEditorVerse(text: $0) }
        verses = existing.isEmpty ? [SongEditorVerse(text: "")] : existing
        refrain = song.refrain
        externalID = song.externalID
    }

    /// Everything that matters when comparing "did anything change".
    var signature: [String] {
        [
            type.rawValue,
            title.trimmingCharacters(in: .whitespacesAndNewlines),
            type == .hymn ? hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : "",
            SongsLogic.cleanedVerses(verses.map { $0.text }).joined(separator: "\u{1F}"),
            refrain.trimmingCharacters(in: .whitespacesAndNewlines),
            externalID ?? ""
        ]
    }

    var hasLyrics: Bool {
        !SongsLogic.cleanedVerses(verses.map { $0.text }).isEmpty
            || !refrain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private enum SongEditorFocus: Hashable {
    case number
    case title
    case verse(UUID)
    case refrain
}

/// Add or edit a song as a full page (pushed, not a sheet): type, hymn number, title with Hymnary suggestions,
/// verses (add, remove, move) and a refrain. Save writes to the library; Cancel throws the edits away.
///
/// `song == nil` means a new song, added by hand (`source == .added`). Choruses and worship songs have no Hymnary
/// lookup: a title and optional lyrics.
struct SongEditorPage: View {
    let song: LibrarySong?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var library: [LibrarySong]

    @State private var draft: SongEditorDraft
    @State private var lookup = HymnaryLookupModel()
    @State private var showDiscard = false
    @State private var duplicateTitle: String?
    @FocusState private var focus: SongEditorFocus?

    private let original: [String]

    init(song: LibrarySong?) {
        self.song = song
        let initial = song.map { SongEditorDraft($0) } ?? SongEditorDraft()
        self._draft = State(initialValue: initial)
        self.original = initial.signature
    }

    private var isNew: Bool { song == nil }

    private var isDirty: Bool { draft.signature != original }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var typeSelection: Binding<SongType> {
        Binding(
            get: { draft.type },
            set: { newValue in
                draft.type = newValue
                if newValue != .hymn { lookup.clear() }
            }
        )
    }

    // MARK: Body

    var body: some View {
        List {
            typeSection
            titleSection
            versesSection
            refrainSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isNew ? "New song" : "Edit song")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .hidesPlusButton()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { cancel() }
                    .accessibilityIdentifier("song-cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("song-save")
            }
            // Always present so moving between fields never rebuilds the keyboard bar mid-tap.
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { focus = nil }
                    .accessibilityIdentifier("keyboard-done")
            }
        }
        .confirmationDialog("Discard your changes?", isPresented: $showDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { dismiss() }
            Button("Keep editing", role: .cancel) {}
        }
        .alert(
            "Already in your songs",
            isPresented: Binding(
                get: { duplicateTitle != nil },
                set: { if !$0 { duplicateTitle = nil } }
            )
        ) {
            Button("OK", role: .cancel) { duplicateTitle = nil }
        } message: {
            Text("\u{201C}\(duplicateTitle ?? "")\u{201D} is already in your songs. Open it from the list to change it.")
        }
        .onChange(of: draft.title) { _, newValue in
            if draft.type == .hymn { lookup.update(query: newValue) }
        }
        .onAppear {
            if isNew { focus = .title }
        }
    }

    // MARK: Type and number

    private var typeSection: some View {
        Section {
            Picker("Song type", selection: typeSelection) {
                ForEach(SongType.allCases, id: \.self) { type in
                    Text(SongLibraryLogic.shortTypeName(type)).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: Theme.minTapTarget)
            .accessibilityIdentifier("song-editor-type")

            if draft.type == .hymn {
                SongEditorLabeledField(
                    label: "Hymn number",
                    placeholder: "e.g. 212",
                    text: $draft.hymnNumber,
                    field: .number,
                    focus: $focus,
                    keyboard: .numberPad,
                    capitalization: .never,
                    identifier: "song-editor-number"
                )
            }
        }
    }

    // MARK: Title and suggestions

    private var titleSection: some View {
        Section {
            SongEditorLabeledField(
                label: "Title",
                placeholder: draft.type == .hymn ? "e.g. Great is thy faithfulness" : "Song title",
                text: $draft.title,
                field: .title,
                focus: $focus,
                capitalization: .sentences,
                identifier: "song-editor-title"
            )
            if draft.type == .hymn {
                HymnarySuggestionRows(model: lookup, identifier: "song-editor") { pick($0) }
                HymnaryLyricsStatusRow(status: lookup.lyricsStatus)
            }
        } footer: {
            if draft.type == .hymn {
                Text("Type a hymn title and pick it from Hymnary to fill in the lyrics. You can also type them yourself.")
            }
        }
    }

    // MARK: Verses

    private var versesSection: some View {
        Section {
            ForEach($draft.verses) { $verse in
                verseRow($verse)
            }
            .onDelete { offsets in
                draft.verses.remove(atOffsets: offsets)
                if draft.verses.isEmpty { draft.verses = [SongEditorVerse(text: "")] }
            }

            Button {
                addVerse()
            } label: {
                Label("Add verse", picon: .plus)
                    .font(.selahBody)
                    .frame(minHeight: Theme.minTapTarget, alignment: .leading)
            }
            .accessibilityIdentifier("song-editor-add-verse")
        } header: {
            Text("Verses")
        } footer: {
            Text("Each verse in its own box, without the verse number.")
        }
    }

    private func verseRow(_ verse: Binding<SongEditorVerse>) -> some View {
        let id = verse.wrappedValue.id
        let position = draft.verses.firstIndex(where: { $0.id == id }) ?? 0
        let count = draft.verses.count
        return HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text("Verse \(position + 1)")
                    .font(.selahLabelSmall)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Type the verse", text: verse.text, axis: .vertical)
                    .font(.selahBody)
                    .lineLimit(2...12)
                    .focused($focus, equals: .verse(id))
                    .textInputAutocapitalization(.sentences)
                    .accessibilityLabel("Verse \(position + 1)")
                    .accessibilityIdentifier("song-editor-verse-\(position)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    move(id, by: -1)
                } label: {
                    Label("Move up", picon: .caretUp)
                }
                .disabled(position == 0)
                Button {
                    move(id, by: 1)
                } label: {
                    Label("Move down", picon: .caretDown)
                }
                .disabled(position >= count - 1)
                Button(role: .destructive) {
                    remove(id)
                } label: {
                    Label("Remove verse", picon: .trash)
                }
            } label: {
                Image(picon: .dotsThree)
                    .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Verse \(position + 1) options")
            .accessibilityIdentifier("song-editor-verse-menu-\(position)")
        }
        .padding(.vertical, Theme.Spacing.xxs)
    }

    // MARK: Refrain

    private var refrainSection: some View {
        Section {
            SongEditorLabeledField(
                label: "Refrain",
                placeholder: "Sung after each verse (optional)",
                text: $draft.refrain,
                field: .refrain,
                focus: $focus,
                axis: .vertical,
                capitalization: .sentences,
                identifier: "song-editor-refrain"
            )
        } header: {
            Text("Refrain or chorus")
        } footer: {
            Text("Leave empty if the song has no refrain.")
        }
    }

    // MARK: Actions

    private func addVerse() {
        let verse = SongEditorVerse(text: "")
        if reduceMotion {
            draft.verses.append(verse)
        } else {
            withAnimation { draft.verses.append(verse) }
        }
        focus = .verse(verse.id)
    }

    private func remove(_ id: UUID) {
        draft.verses.removeAll { $0.id == id }
        if draft.verses.isEmpty { draft.verses = [SongEditorVerse(text: "")] }
    }

    private func move(_ id: UUID, by step: Int) {
        guard let from = draft.verses.firstIndex(where: { $0.id == id }) else { return }
        let to = from + step
        guard draft.verses.indices.contains(to) else { return }
        if reduceMotion {
            draft.verses.swapAt(from, to)
        } else {
            withAnimation { draft.verses.swapAt(from, to) }
        }
    }

    private func cancel() {
        focus = nil
        if isDirty {
            showDiscard = true
        } else {
            dismiss()
        }
    }

    /// The user picked a Hymnary suggestion: the title and Hymnary id are filled in, then the lyrics are fetched and
    /// filled in when the verse boxes are still empty (typed lyrics are never replaced). The user confirms with Save.
    private func pick(_ result: HymnarySearchResult) {
        let title = result.suggestedTitle
        draft.type = .hymn
        draft.title = title
        draft.externalID = result.textAuthNumber
        lookup.didPick(title: title)
        focus = nil

        guard !draft.hasLyrics else {
            lookup.markAlreadyHaveLyrics()
            return
        }
        Task {
            guard let lyrics = await lookup.fetchLyrics(for: result) else { return }
            // Typing may have started while the lyrics were loading.
            guard !draft.hasLyrics else { return }
            let verses = lyrics.verses.map { SongEditorVerse(text: $0) }
            draft.verses = verses.isEmpty ? [SongEditorVerse(text: "")] : verses
            draft.refrain = lyrics.refrain ?? ""
            draft.importedLyrics = true
        }
    }

    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let type = draft.type
        let number = type == .hymn ? draft.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let verses = SongsLogic.cleanedVerses(draft.verses.map { $0.text })
        let refrain = draft.refrain.trimmingCharacters(in: .whitespacesAndNewlines)

        // Another song with this title and type: the user opens that one instead of making a twin.
        let others = library.filter { $0 !== song }
        let key = SongKey(title: title, type: type, hymnNumber: number)
        if SongLibraryLogic.matchIndex(for: key, in: others.map { $0.key }) != nil {
            duplicateTitle = title
            return
        }

        let target: LibrarySong
        if let song {
            target = song
        } else {
            target = LibrarySong(source: .added)
            modelContext.insert(target)
        }
        let identityChanged = target.title != title || target.songType != type || target.hymnNumber != number

        target.title = title
        target.songType = type
        target.hymnNumber = number
        target.lyricVerses = verses
        target.refrain = refrain
        target.externalID = draft.externalID

        if target.hasLyrics {
            if draft.importedLyrics { target.source = .imported }
        } else if target.source == .imported {
            target.source = .added
        }

        if identityChanged && !isNew {
            SongLibrary.propagateIdentity(of: target)
        }
        try? modelContext.save()
        focus = nil
        dismiss()
    }
}

// MARK: - Field

/// A text field with a small label above it that stays when the field is filled (same look as the service page).
private struct SongEditorLabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let field: SongEditorFocus
    var focus: FocusState<SongEditorFocus?>.Binding
    var axis: Axis = .horizontal
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words
    let identifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.selahLabelSmall)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text, axis: axis)
                .font(.selahBody)
                .lineLimit(axis == .vertical ? 1...8 : 1...1)
                .focused(focus, equals: field)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .accessibilityLabel(label)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

#Preview("New song") {
    NavigationStack {
        SongEditorPage(song: nil)
    }
    .environment(AppRouter())
    .modelContainer(SampleData.container)
}

#Preview("Edit song") {
    NavigationStack {
        SongEditorPreview()
    }
    .environment(AppRouter())
    .modelContainer(SampleData.container)
}

private struct SongEditorPreview: View {
    @Query(sort: \LibrarySong.title) private var songs: [LibrarySong]

    var body: some View {
        if let song = songs.first(where: { $0.hasLyrics }) {
            SongEditorPage(song: song)
        } else {
            Text("No sample song")
        }
    }
}

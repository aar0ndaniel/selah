import SwiftUI
import SwiftData

/// Write or edit a personal note. A new note is added to the store as soon as the sheet opens (so highlight
/// comments have somewhere to live) and is taken back out if you tap Cancel or close it with nothing written.
struct PersonalNoteSheet: View {
    let isNew: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var note: PersonalNote
    @State private var didSetUp = false
    @State private var isRemoved = false
    @State private var doneCount = 0

    /// Pass nil to write a new note.
    init(note: PersonalNote?) {
        self.isNew = note == nil
        _note = State(initialValue: note ?? PersonalNote())
    }

    var body: some View {
        NavigationStack {
            PersonalNoteForm(note: note)
                .scrollContentBackground(.hidden)
                .background { AppBackground() }
                .navigationTitle(isNew ? "New note" : "Note")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if isNew {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { discard() }
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            doneCount += 1
                            dismiss()
                        }
                    }
                }
                .sensoryFeedback(.success, trigger: doneCount)
        }
        .presentationDetents([.large])
        .onAppear {
            guard !didSetUp else { return }
            didSetUp = true
            if isNew { modelContext.insert(note) }
        }
        .onDisappear {
            // Closed by swiping down with nothing written: do not leave an empty note behind.
            if isNew && !isRemoved && isEmpty {
                remove()
            }
        }
    }

    private var isEmpty: Bool {
        note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && note.body.characters.isEmpty
            && note.verses.isEmpty
    }

    private func discard() {
        remove()
        dismiss()
    }

    private func remove() {
        guard !isRemoved else { return }
        isRemoved = true
        modelContext.delete(note)
        try? modelContext.save()
    }
}

// MARK: - Form

private struct PersonalNoteForm: View {
    @Bindable var note: PersonalNote

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var profiles: [UserProfile]
    @State private var showVersePicker = false

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    var body: some View {
        Form {
            Section {
                TextField("Title", text: $note.title)
                    .font(.headline)
                    .frame(minHeight: 44)
            }

            Section("Colour") {
                ColourPicker(selection: $note.colour)
                Toggle("Pin to top", isOn: $note.pinned)
                    .frame(minHeight: 44)
            }

            Section("Verses") {
                ForEach(note.verses, id: \.persistentModelID) { verse in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(verse.reference)
                            .font(.headline)
                        if !verse.textSnapshot.isEmpty {
                            Text(verse.textSnapshot)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .swipeActions(edge: .trailing) {
                        Button("Remove", role: .destructive) { remove(verse) }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAction(named: "Remove verse") { remove(verse) }
                }
                Button {
                    showVersePicker = true
                } label: {
                    PLabel("Add a verse", icon: .plusCircle)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
            }

            Section("Note") {
                RichNoteEditor(
                    text: $note.body,
                    owner: .personal(note),
                    field: .body,
                    placeholder: "Write your note"
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
        }
        // Pushed inside this sheet's stack rather than a second sheet on top.
        .navigationDestination(isPresented: $showVersePicker) {
            VersePicker(translation: translation, embedded: true) { ref in
                ref.part = .none
                modelContext.insert(ref)
                ref.personalNote = note
                note.updatedAt = Date()
            }
        }
        .onChange(of: note.title) { _, _ in note.updatedAt = Date() }
        .onChange(of: note.colour) { _, _ in note.updatedAt = Date() }
        .onChange(of: note.pinned) { _, _ in note.updatedAt = Date() }
        .onChange(of: note.bodyData) { _, _ in note.updatedAt = Date() }
    }

    private func remove(_ verse: VerseRef) {
        modelContext.delete(verse)
        note.updatedAt = Date()
    }
}

// MARK: - Colour picker

private struct ColourPicker: View {
    @Binding var selection: NoteColour

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            ForEach(NoteColour.allCases, id: \.self) { colour in
                swatch(colour)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func swatch(_ colour: NoteColour) -> some View {
        let isSelected = colour == selection
        return Button {
            selection = colour
        } label: {
            ZStack {
                Circle().fill(colour.color)
                Circle().strokeBorder(
                    isSelected ? Color.accentColor : Color.secondary.opacity(0.4),
                    lineWidth: isSelected ? 3 : 1
                )
                if isSelected {
                    PIconView(.check, size: 16, relativeTo: .footnote)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colour.rawValue.capitalized)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("New note") {
    PersonalNoteSheet(note: nil)
        .modelContainer(SampleData.container)
}

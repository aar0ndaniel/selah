import SwiftUI
import SwiftData

/// Write or edit a personal note as a full page (pushed, never a sheet).
/// The caller adds a new note to the store before pushing this page, so highlight comments have somewhere to live,
/// and removes it again when the page closes with nothing written (see `PersonalNote.isBlank`).
struct PersonalNotePage: View {
    @Bindable var note: PersonalNote
    let isNew: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var profiles: [UserProfile]

    @State private var showVersePicker = false
    @State private var pinCount = 0

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                TextField("Title", text: $note.title, axis: .vertical)
                    .font(.selahDisplay)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .accessibilityLabel("Title")

                ToneSwatches(selection: $note.colour)

                versesSection

                RichNoteEditor(
                    text: $note.body,
                    owner: .personal(note),
                    field: .body,
                    placeholder: "Write your note",
                    embedded: true
                )
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle(isNew ? "New note" : "Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    note.pinned.toggle()
                    pinCount += 1
                } label: {
                    PIconView(.pushPin, filled: note.pinned, size: 22)
                        .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                }
                .accessibilityLabel("Pin note")
                .accessibilityValue(note.pinned ? "On" : "Off")
                .accessibilityAddTraits(.isToggle)
            }
        }
        .sensoryFeedback(.selection, trigger: pinCount)
        // Pushed on the same stack, so the page keeps its back button.
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
        .hidesPlusButton()
    }

    // MARK: Verses

    @ViewBuilder
    private var versesSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(note.verses, id: \.persistentModelID) { verse in
                SurfaceCard {
                    HStack(alignment: .top, spacing: Theme.Spacing.s) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Pill(text: verse.reference, icon: .quotes, tone: note.colour.tone)
                            if !verse.textSnapshot.isEmpty {
                                Text(verse.textSnapshot)
                                    .font(.selahVerseCompact)
                                    .foregroundStyle(.primary)
                                    .lineLimit(typeSize.isAccessibilitySize ? nil : 4)
                            }
                        }
                        Spacer(minLength: 0)
                        Button {
                            remove(verse)
                        } label: {
                            PIconView(.x, size: 18)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(verse.reference)")
                    }
                }
            }
            Button {
                showVersePicker = true
            } label: {
                PLabel("Add a verse", icon: .plusCircle, textStyle: .subheadline)
            }
            .buttonStyle(.selahSecondary())
        }
    }

    private func remove(_ verse: VerseRef) {
        modelContext.delete(verse)
        note.updatedAt = Date()
    }
}

extension PersonalNote {
    /// Nothing written yet: no title, no text, no verses.
    var isBlank: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && body.characters.isEmpty
            && verses.isEmpty
    }
}

// MARK: - Colour swatches

/// Six note colours as round swatches. The selected one is ringed and carries a check, so colour is not the only cue.
private struct ToneSwatches: View {
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
        let tone = colour.tone
        return Button {
            selection = colour
        } label: {
            ZStack {
                Circle().fill(tone.fill)
                Circle().strokeBorder(
                    tone.ink.opacity(isSelected ? 1 : 0.3),
                    lineWidth: isSelected ? 2.5 : 1
                )
                if isSelected {
                    PIconView(.check, size: 16, relativeTo: .footnote)
                        .foregroundStyle(tone.ink)
                }
            }
            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tone.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("New note") {
    NavigationStack {
        PersonalNotePage(note: PersonalNote(title: "Rest", colour: .sky), isNew: true)
    }
    .environment(AppRouter())
    .modelContainer(SampleData.container)
}

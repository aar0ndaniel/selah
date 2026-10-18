import SwiftUI

/// Finds a passage by typing a reference. Tap a result to hand back a `VerseRef`.
///
/// By default it is a sheet with its own navigation stack. With `embedded: true` it has no stack of its own,
/// so it can be pushed inside a sheet that already has one (no sheet on top of a sheet).
struct VersePicker: View {
    let translation: Translation
    let embedded: Bool
    let onPick: (VerseRef) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var query = ""

    init(translation: Translation, embedded: Bool = false, onPick: @escaping (VerseRef) -> Void) {
        self.translation = translation
        self.embedded = embedded
        self.onPick = onPick
    }

    private let parser = ReferenceParser()

    private struct Passage: Identifiable {
        let reference: BibleReference
        let verses: [Verse]
        var id: BibleReference { reference }
        var text: String { BibleStore.joined(verses) }
    }

    private func passage(for reference: BibleReference) -> Passage {
        Passage(
            reference: reference,
            verses: BibleStore.shared.verses(for: reference, translation: translation)
        )
    }

    var body: some View {
        if embedded {
            picker
        } else {
            NavigationStack {
                picker
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { dismiss() }
                        }
                    }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var picker: some View {
        content
            .navigationTitle("Add a verse")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "John 3:16 or Psalm 23"
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            popularList
        } else if let reference = parser.parse(trimmed) {
            let found = passage(for: reference)
            if found.verses.isEmpty {
                ContentUnavailableView {
                    Label {
                        Text("Verse not found")
                    } icon: {
                        PIconView(.book, size: 48, relativeTo: .largeTitle)
                    }
                } description: {
                    Text("\(reference.displayString) is not in \(translation.rawValue.uppercased()).")
                }
            } else {
                List {
                    Section {
                        row(for: found, showText: true)
                    } header: {
                        Text("Result")
                    } footer: {
                        Text("Showing \(translation.rawValue.uppercased())")
                    }
                }
            }
        } else {
            let names = parser.suggestions(for: trimmed)
            if names.isEmpty {
                ContentUnavailableView.search(text: trimmed)
            } else {
                List {
                    Section("Books") {
                        ForEach(names, id: \.self) { name in
                            Button {
                                query = name + " "
                            } label: {
                                Text(name)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(name)
                            .accessibilityHint("Fills in the book name")
                        }
                    }
                }
            }
        }
    }

    private var popularList: some View {
        List {
            Section("Popular passages") {
                ForEach(PopularPassages.all, id: \.self) { reference in
                    row(for: passage(for: reference), showText: true)
                }
            }
        }
    }

    @ViewBuilder
    private func row(for passage: Passage, showText: Bool) -> some View {
        Button {
            pick(passage)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(passage.reference.displayString)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if showText, !passage.text.isEmpty {
                    Text(passage.text)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(query.isEmpty && !typeSize.isAccessibilitySize ? 2 : nil)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(passage.reference.displayString). \(passage.text)")
        .accessibilityHint("Adds this passage")
    }

    private func pick(_ passage: Passage) {
        guard let first = passage.verses.first, let last = passage.verses.last else { return }
        let ref = VerseRef(
            book: passage.reference.bookName,
            chapter: passage.reference.chapter,
            verseStart: first.number,
            verseEnd: last.number,
            translation: translation,
            textSnapshot: passage.text,
            part: .none
        )
        onPick(ref)
        dismiss()
    }
}

#Preview {
    VersePicker(translation: .kjv) { _ in }
}

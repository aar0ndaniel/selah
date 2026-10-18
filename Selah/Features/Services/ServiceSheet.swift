import SwiftUI
import SwiftData

/// One recorded service: sermon, Bible class and songs. Presented as a sheet.
struct ServiceSheet: View {
    @Bindable var service: Service

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var meetingDays: [MeetingDay]
    @Query private var profiles: [UserProfile]

    @State private var pickerPart: VersePart?
    /// True while the gathering type is "Other" and the name is typed by hand.
    @State private var isOther = false
    @State private var didSetUp = false

    private static let otherTag = "__other__"

    private var translation: Translation { profiles.first?.translation ?? .kjv }

    private var gatheringNames: [String] {
        var seen: [String] = []
        for day in meetingDays.sorted(by: MeetingDay.scheduleOrder) {
            let name = day.displayName
            if !name.isEmpty && !seen.contains(name) { seen.append(name) }
        }
        return seen
    }

    private var gatheringSelection: Binding<String> {
        Binding(
            get: { isOther ? Self.otherTag : service.gatheringName },
            set: { newValue in
                if newValue == Self.otherTag {
                    isOther = true
                    if gatheringNames.contains(service.gatheringName) {
                        service.gatheringName = "Service"
                    }
                } else {
                    isOther = false
                    service.gatheringName = newValue
                }
            }
        )
    }

    private var sortedSongs: [Song] { service.songs.sorted { $0.order < $1.order } }

    private func verses(for part: VersePart) -> [VerseRef] {
        service.verses.filter { $0.part == part }
    }

    var body: some View {
        NavigationStack {
            Form {
                gatheringSection
                sermonSection
                classSection
                songsSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(service.gatheringName.isEmpty ? "Service" : service.gatheringName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: pickerIsPresented) {
                VersePicker(translation: translation) { ref in
                    addVerse(ref)
                }
            }
            .onAppear {
                guard !didSetUp else { return }
                didSetUp = true
                let name = service.gatheringName
                isOther = !name.isEmpty && !gatheringNames.contains(name)
            }
        }
        .presentationDetents([.large])
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(
            get: { pickerPart != nil },
            set: { if !$0 { pickerPart = nil } }
        )
    }

    // MARK: Sections

    private var gatheringSection: some View {
        Section {
            DatePicker("Date", selection: $service.date, displayedComponents: .date)
            Picker("Gathering", selection: gatheringSelection) {
                ForEach(gatheringNames, id: \.self) { name in
                    Text(name).tag(name)
                }
                Text("Other").tag(Self.otherTag)
            }
            if isOther {
                TextField("Gathering name", text: $service.gatheringName)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private var sermonSection: some View {
        Section {
            TextField("Title", text: $service.sermonTitle, axis: .vertical)
                .textInputAutocapitalization(.words)
            TextField("Sermonist", text: $service.sermonist)
                .textInputAutocapitalization(.words)
            verseRows(for: .sermon)
            RichNoteEditor(
                text: $service.sermonNote,
                owner: .service(service),
                field: .sermon,
                placeholder: "Sermon message"
            )
            Toggle(
                "Favourite sermon",
                systemImage: service.sermonFavourite ? "star.fill" : "star",
                isOn: $service.sermonFavourite
            )
            .frame(minHeight: 44)
        } header: {
            Text("Sermon")
        }
    }

    private var classSection: some View {
        Section {
            TextField("Lesson", text: $service.classLesson, axis: .vertical)
                .textInputAutocapitalization(.words)
            TextField("Taught by", text: $service.classTeacher)
                .textInputAutocapitalization(.words)
            verseRows(for: .bibleClass)
            RichNoteEditor(
                text: $service.classNote,
                owner: .service(service),
                field: .bibleClass,
                placeholder: "Class notes"
            )
            Toggle(
                "Favourite Bible class",
                systemImage: service.classFavourite ? "star.fill" : "star",
                isOn: $service.classFavourite
            )
            .frame(minHeight: 44)
        } header: {
            Text("Bible class")
        }
    }

    private var songsSection: some View {
        Section {
            ForEach(sortedSongs) { song in
                SongRow(song: song)
            }
            .onDelete(perform: deleteSongs)
            .onMove(perform: moveSongs)

            Button {
                addSong()
            } label: {
                Label("Add a song", systemImage: "plus.circle.fill")
                    .frame(minHeight: 44, alignment: .leading)
            }
        } header: {
            Text("Songs")
        }
    }

    // MARK: Verses

    @ViewBuilder
    private func verseRows(for part: VersePart) -> some View {
        ForEach(verses(for: part)) { verse in
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(verse.reference)
                    .font(.headline)
                if !verse.textSnapshot.isEmpty {
                    Text(verse.textSnapshot)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityElement(children: .combine)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    deleteVerse(verse)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button(role: .destructive) {
                    deleteVerse(verse)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        Button {
            pickerPart = part
        } label: {
            Label("Add a verse", systemImage: "book")
                .frame(minHeight: 44, alignment: .leading)
        }
    }

    private func addVerse(_ ref: VerseRef) {
        guard let part = pickerPart else { return }
        ref.part = part
        modelContext.insert(ref)
        ref.service = service
    }

    private func deleteVerse(_ verse: VerseRef) {
        modelContext.delete(verse)
    }

    // MARK: Songs

    private func addSong() {
        let next = (service.songs.map { $0.order }.max() ?? -1) + 1
        let song = Song(order: next)
        modelContext.insert(song)
        song.service = service
    }

    private func deleteSongs(at offsets: IndexSet) {
        let current = sortedSongs
        for index in offsets {
            modelContext.delete(current[index])
        }
        renumber(current.enumerated().filter { !offsets.contains($0.offset) }.map { $0.element })
    }

    private func moveSongs(from source: IndexSet, to destination: Int) {
        var current = sortedSongs
        current.move(fromOffsets: source, toOffset: destination)
        renumber(current)
    }

    private func renumber(_ songs: [Song]) {
        for (index, song) in songs.enumerated() {
            song.order = index
        }
    }
}

private struct SongRow: View {
    @Bindable var song: Song

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            TextField("Hymn number", text: $song.hymnNumber)
                .keyboardType(.numbersAndPunctuation)
                .frame(width: 96)
                .accessibilityLabel("Hymn number")
            TextField("Song title", text: $song.title)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Song title")
        }
        .frame(minHeight: 44)
    }
}

#Preview {
    ServiceSheet(service: Service(
        date: Date(),
        gatheringName: "Sunday worship",
        sermonTitle: "Grace upon grace",
        sermonist: "Pastor Mensah"
    ))
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

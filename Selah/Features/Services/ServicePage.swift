import SwiftUI
import SwiftData

/// One recorded service as a full page: sermon, Bible class and songs.
///
/// Pushed in the Services `NavigationStack` (no stack of its own, no sheet). Anything that still wants to present
/// a service in a sheet (Today, Notes) uses `ServiceSheet`, which wraps this page in a stack.
struct ServicePage: View {
    @Bindable var service: Service

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @Query private var meetingDays: [MeetingDay]
    @Query private var profiles: [UserProfile]

    @State private var pickerPart: VersePart?
    /// True while the gathering type is "Other" and the name is typed by hand.
    @State private var isOther = false
    @State private var didSetUp = false
    @State private var showDatePicker = false
    @State private var sermonOpen: Bool
    @State private var classOpen: Bool
    @State private var songsOpen = true

    private static let otherTag = "__other__"

    init(service: Service) {
        self._service = Bindable(service)
        let sermon = ServicesLogic.sectionHasContent(
            texts: [service.sermonTitle, service.sermonist],
            hasNote: !service.sermonNote.characters.isEmpty,
            verseCount: service.verses.filter { $0.part == .sermon }.count
        )
        let bibleClass = ServicesLogic.sectionHasContent(
            texts: [service.classLesson, service.classTeacher],
            hasNote: !service.classNote.characters.isEmpty,
            verseCount: service.verses.filter { $0.part == .bibleClass }.count
        )
        let start = ServicesLogic.initialExpansion(sermonHasContent: sermon, classHasContent: bibleClass)
        self._sermonOpen = State(initialValue: start.sermon)
        self._classOpen = State(initialValue: start.bibleClass)
    }

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

    private var gatheringTitle: String {
        service.gatheringName.isEmpty ? "Service" : service.gatheringName
    }

    private var dateText: String {
        service.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    private var sortedSongs: [Song] { service.songs.sorted { $0.order < $1.order } }

    private func verses(for part: VersePart) -> [VerseRef] {
        service.verses.filter { $0.part == part }
    }

    var body: some View {
        List {
            headerSection
            sermonSection
            classSection
            songsSection
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .hidesPlusButton()
        .toolbar {
            if sortedSongs.count > 1 {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        // Pushed in the same stack rather than shown as a sheet.
        .navigationDestination(isPresented: pickerIsPresented) {
            VersePicker(translation: translation, embedded: true) { ref in
                addVerse(ref)
            }
        }
        .sheet(isPresented: $showDatePicker) { datePickerSheet }
        .sensoryFeedback(.impact(weight: .light), trigger: service.sermonFavourite)
        .sensoryFeedback(.impact(weight: .light), trigger: service.classFavourite)
        .onAppear {
            guard !didSetUp else { return }
            didSetUp = true
            let name = service.gatheringName
            isOther = !name.isEmpty && !gatheringNames.contains(name)
        }
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(
            get: { pickerPart != nil },
            set: { if !$0 { pickerPart = nil } }
        )
    }

    // MARK: Header

    private var headerSection: some View {
        Section {
            HStack(spacing: Theme.Spacing.s) {
                Text(dateText)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Button {
                    showDatePicker = true
                } label: {
                    PIconView(.calendarBlank, size: 22)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Change date")
                .accessibilityHint("Moves this service to another day")
            }

            Picker("Gathering", selection: gatheringSelection) {
                ForEach(gatheringNames, id: \.self) { name in
                    Text(name).tag(name)
                }
                Text("Other").tag(Self.otherTag)
            }
            .pickerStyle(.menu)
            .accessibilityHint("Changes the type of gathering")

            if isOther {
                TextField("Gathering name", text: $service.gatheringName)
                    .textInputAutocapitalization(.sentences)
            }
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            ScrollView {
                DatePicker("Date", selection: $service.date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, Theme.Spacing.m)
            }
            .navigationTitle("Move service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showDatePicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Collapsible sections
    //
    // Section(isExpanded:) only collapses in a `.sidebar` list (Apple's Section docs), so each collapsible part is a
    // native DisclosureGroup: the first row of an inset grouped section, with the content rows inside it.

    private var sermonSection: some View {
        Section {
            DisclosureGroup(isExpanded: $sermonOpen) {
                TextField("Title", text: $service.sermonTitle, axis: .vertical)
                    .textInputAutocapitalization(.words)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityLabel("Sermon title")
                TextField("Sermonist", text: $service.sermonist)
                    .textInputAutocapitalization(.words)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityLabel("Sermonist")
                verseRows(for: .sermon)
                RichNoteEditor(
                    text: $service.sermonNote,
                    owner: .service(service),
                    field: .sermon,
                    placeholder: "Sermon message",
                    embedded: true
                )
                .padding(.vertical, Theme.Spacing.xs)
            } label: {
                disclosureLabel(
                    title: "Sermon",
                    isFavourite: service.sermonFavourite,
                    favouriteLabel: "Favourite sermon",
                    toggleFavourite: { service.sermonFavourite.toggle() }
                )
            }
        }
    }

    private var classSection: some View {
        Section {
            DisclosureGroup(isExpanded: $classOpen) {
                TextField("Lesson", text: $service.classLesson, axis: .vertical)
                    .textInputAutocapitalization(.words)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityLabel("Lesson")
                TextField("Taught by", text: $service.classTeacher)
                    .textInputAutocapitalization(.words)
                    .frame(minHeight: Theme.minTapTarget)
                    .accessibilityLabel("Taught by")
                verseRows(for: .bibleClass)
                RichNoteEditor(
                    text: $service.classNote,
                    owner: .service(service),
                    field: .bibleClass,
                    placeholder: "Class notes",
                    embedded: true
                )
                .padding(.vertical, Theme.Spacing.xs)
            } label: {
                disclosureLabel(
                    title: "Bible class",
                    isFavourite: service.classFavourite,
                    favouriteLabel: "Favourite Bible class",
                    toggleFavourite: { service.classFavourite.toggle() }
                )
            }
        }
    }

    /// Disclosure row title with an icon-only favourite star beside the system chevron.
    private func disclosureLabel(
        title: String,
        isFavourite: Bool,
        favouriteLabel: String,
        toggleFavourite: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            Button(action: toggleFavourite) {
                PIconView(.star, filled: isFavourite, size: 22)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(favouriteLabel)
            .accessibilityValue(isFavourite ? "On" : "Off")
            .accessibilityAddTraits(isFavourite ? .isSelected : [])
        }
    }

    // MARK: Verses

    @ViewBuilder
    private func verseRows(for part: VersePart) -> some View {
        ForEach(verses(for: part)) { verse in
            verseRow(verse)
        }
        Button {
            pickerPart = part
        } label: {
            PLabel("Add verse", icon: .plus, size: 18)
                .frame(minHeight: Theme.minTapTarget, alignment: .leading)
        }
        .accessibilityHint("Finds a verse to attach")
    }

    private func verseRow(_ verse: VerseRef) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(verse.reference)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
            if !verse.textSnapshot.isEmpty {
                Text(verse.textSnapshot)
                    .font(.selahVerseCompact)
                    .foregroundStyle(.primary)
                    .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deleteVerse(verse)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                deleteVerse(verse)
            } label: {
                Label("Delete", picon: .trash)
            }
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

    private var songsSection: some View {
        Section {
            DisclosureGroup(isExpanded: $songsOpen) {
                let songs = sortedSongs
                ForEach(Array(songs.enumerated()), id: \.element.persistentModelID) { index, song in
                    SongRow(
                        song: song,
                        position: index + 1,
                        canMoveUp: ServicesLogic.movedIndex(index, by: -1, count: songs.count) != nil,
                        canMoveDown: ServicesLogic.movedIndex(index, by: 1, count: songs.count) != nil,
                        onMove: { step in moveSong(at: index, by: step) },
                        onDelete: { deleteSong(at: index) }
                    )
                }
                .onMove(perform: reorderSongs)
                Button(action: addSong) {
                    PLabel("Add song", icon: .musicNotes, size: 18)
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
            } label: {
                Text("Songs")
                    .font(.headline)
                    .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
        }
    }

    private func addSong() {
        let next = (service.songs.map { $0.order }.max() ?? -1) + 1
        let song = Song(order: next)
        modelContext.insert(song)
        song.service = service
    }

    private func deleteSong(at index: Int) {
        let current = sortedSongs
        guard current.indices.contains(index) else { return }
        modelContext.delete(current[index])
        var remaining = current
        remaining.remove(at: index)
        renumber(remaining)
    }

    private func moveSong(at index: Int, by step: Int) {
        var current = sortedSongs
        guard let target = ServicesLogic.movedIndex(index, by: step, count: current.count) else { return }
        current.swapAt(index, target)
        renumber(current)
    }

    private func reorderSongs(from source: IndexSet, to destination: Int) {
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

// MARK: - Song row

/// One song row: hymn number above, title below, so typing never hides words. Swipe to delete;
/// Move up / Move down in the long-press menu for VoiceOver and Switch Control (drag handles show in Edit mode).
private struct SongRow: View {
    @Bindable var song: Song
    let position: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("Hymn number", text: $song.hymnNumber)
                .keyboardType(.numberPad)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .accessibilityLabel("Song \(position) hymn number")
            TextField("Song title", text: $song.title)
                .textInputAutocapitalization(.words)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .accessibilityLabel("Song \(position) title")
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            Button { onMove(-1) } label: { Label("Move up", picon: .caretUp) }
                .disabled(!canMoveUp)
            Button { onMove(1) } label: { Label("Move down", picon: .caretDown) }
                .disabled(!canMoveDown)
            Button(role: .destructive, action: onDelete) {
                Label("Delete song", picon: .trash)
            }
        }
    }
}

// MARK: - Sheet wrapper

/// Presents a service in a sheet (used by Today and Notes). The Services tab pushes `ServicePage` instead.
/// Same init as before the redesign, so existing call sites keep compiling.
struct ServiceSheet: View {
    let service: Service

    @Environment(\.dismiss) private var dismiss

    init(service: Service) {
        self.service = service
    }

    var body: some View {
        NavigationStack {
            ServicePage(service: service)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
    }
}

#Preview("Service page") {
    NavigationStack {
        ServicePage(service: Service(
            date: Date(),
            gatheringName: "Sunday worship",
            sermonTitle: "Grace upon grace",
            sermonist: "Pastor Mensah"
        ))
    }
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

#Preview("Service sheet") {
    ServiceSheet(service: Service(
        date: Date(),
        gatheringName: "Sunday worship",
        sermonTitle: "Grace upon grace",
        sermonist: "Pastor Mensah"
    ))
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

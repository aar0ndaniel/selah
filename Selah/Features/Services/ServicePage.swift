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
    @FocusState private var focus: ServiceField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        ScrollViewReader { proxy in
            List {
                headerSection
                sermonSection
                classSection
                songsSection(proxy: proxy)
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
                // The number pad has no return key, so every field gets a way to close the keyboard.
                // Always present: adding/removing it as focus changes rebuilt the keyboard bar mid-tap
                // and the next field lost focus.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focus = nil }
                        .accessibilityIdentifier("keyboard-done")
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
                    .font(.selahCardTitle)
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
                LabeledField(
                    label: "Gathering name",
                    placeholder: "e.g. Midweek service",
                    text: $service.gatheringName,
                    field: .gathering,
                    focus: $focus,
                    capitalization: .sentences,
                    identifier: "field-gathering-name"
                )
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
                LabeledField(
                    label: "Title",
                    placeholder: "e.g. Grace that keeps",
                    text: $service.sermonTitle,
                    field: .sermonTitle,
                    focus: $focus,
                    axis: .vertical,
                    identifier: "field-sermon-title"
                )
                LabeledField(
                    label: "Sermonist",
                    placeholder: "e.g. Pastor Mensah",
                    text: $service.sermonist,
                    field: .sermonist,
                    focus: $focus,
                    identifier: "field-sermonist"
                )
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
                    isExpanded: $sermonOpen,
                    identifier: "section-sermon",
                    favouriteIdentifier: "favourite-sermon",
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
                LabeledField(
                    label: "Lesson",
                    placeholder: "e.g. Walking in the Spirit",
                    text: $service.classLesson,
                    field: .classLesson,
                    focus: $focus,
                    axis: .vertical,
                    identifier: "field-class-lesson"
                )
                LabeledField(
                    label: "Taught by",
                    placeholder: "e.g. Deacon Owusu",
                    text: $service.classTeacher,
                    field: .classTeacher,
                    focus: $focus,
                    identifier: "field-class-teacher"
                )
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
                    isExpanded: $classOpen,
                    identifier: "section-class",
                    favouriteIdentifier: "favourite-class",
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
        isExpanded: Binding<Bool>,
        identifier: String,
        favouriteIdentifier: String,
        isFavourite: Bool,
        favouriteLabel: String,
        toggleFavourite: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            toggleLabel(title: title, isExpanded: isExpanded, identifier: identifier)
            Button(action: toggleFavourite) {
                PIconView(.star, filled: isFavourite, size: 22)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(favouriteIdentifier)
            .accessibilityLabel(favouriteLabel)
            .accessibilityValue(isFavourite ? "On" : "Off")
            .accessibilityAddTraits(isFavourite ? .isSelected : [])
        }
    }

    /// The title area of a disclosure row. It fills the row and toggles expansion itself, so tapping anywhere
    /// except the star opens or closes the section (the system label tap alone proved unreliable).
    private func toggleLabel(title: String, isExpanded: Binding<Bool>, identifier: String) -> some View {
        Text(title)
            .font(.selahCardTitle)
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                if reduceMotion {
                    isExpanded.wrappedValue.toggle()
                } else {
                    withAnimation(.snappy) { isExpanded.wrappedValue.toggle() }
                }
            }
            .accessibilityIdentifier(identifier)
            .accessibilityAddTraits([.isHeader, .isButton])
            .accessibilityValue(isExpanded.wrappedValue ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows or hides this section")
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
                .font(.selahLabel.weight(.semibold))
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

    private func songsSection(proxy: ScrollViewProxy) -> some View {
        Section {
            DisclosureGroup(isExpanded: $songsOpen) {
                let songs = sortedSongs
                ForEach(Array(songs.enumerated()), id: \.element.persistentModelID) { index, song in
                    SongRow(
                        song: song,
                        position: index + 1,
                        focus: $focus,
                        canMoveUp: ServicesLogic.movedIndex(index, by: -1, count: songs.count) != nil,
                        canMoveDown: ServicesLogic.movedIndex(index, by: 1, count: songs.count) != nil,
                        onMove: { step in moveSong(at: index, by: step) },
                        onDelete: { deleteSong(at: index) }
                    )
                }
                .onMove(perform: reorderSongs)
                Button { addSong(proxy: proxy) } label: {
                    PLabel("Add song", icon: .musicNotes, size: 18)
                        .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                }
                .accessibilityIdentifier("add-song")
            } label: {
                toggleLabel(title: "Songs", isExpanded: $songsOpen, identifier: "section-songs")
            }
        }
    }

    private func addSong(proxy: ScrollViewProxy) {
        let next = (service.songs.map { $0.order }.max() ?? -1) + 1
        let song = Song(order: next)
        modelContext.insert(song)
        song.service = service
        // Save now so the row id is the permanent one; a temporary id would change on autosave and drop the focus.
        try? modelContext.save()
        let id = song.persistentModelID
        Task { @MainActor in
            // Let the List lay out the new row before scrolling to it.
            try? await Task.sleep(for: .milliseconds(200))
            if reduceMotion {
                proxy.scrollTo(id, anchor: .center)
            } else {
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
            focus = .hymn(id)
        }
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

// MARK: - Fields

/// Which text field has focus on the service page.
enum ServiceField: Hashable {
    case gathering, sermonTitle, sermonist, classLesson, classTeacher
    case hymn(PersistentIdentifier)
    case songTitle(PersistentIdentifier)
}

/// A text field with a small label above it that stays when the field is filled; the placeholder is an example.
private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let field: ServiceField
    var focus: FocusState<ServiceField?>.Binding
    var axis: Axis = .horizontal
    var keyboard: UIKeyboardType = .default
    var capitalization: TextInputAutocapitalization = .words
    let identifier: String
    var accessibilityLabel: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.selahLabelSmall)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField(placeholder, text: $text, axis: axis)
                .focused(focus, equals: field)
                .keyboardType(keyboard)
                .textInputAutocapitalization(capitalization)
                .accessibilityLabel(accessibilityLabel ?? label)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
        .padding(.vertical, Theme.Spacing.xxs)
    }
}

// MARK: - Song row

/// One song row: hymn number above, title below, so typing never hides words. Swipe to delete;
/// Move up / Move down in the long-press menu for VoiceOver and Switch Control (drag handles show in Edit mode).
private struct SongRow: View {
    @Bindable var song: Song
    let position: Int
    var focus: FocusState<ServiceField?>.Binding
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            LabeledField(
                label: "Hymn number",
                placeholder: "e.g. 212",
                text: $song.hymnNumber,
                field: .hymn(song.persistentModelID),
                focus: focus,
                keyboard: .numberPad,
                capitalization: .never,
                identifier: "field-hymn-number",
                accessibilityLabel: "Hymn number, song \(position)"
            )
            LabeledField(
                label: "Song title",
                placeholder: "e.g. Great is thy faithfulness",
                text: $song.title,
                field: .songTitle(song.persistentModelID),
                focus: focus,
                identifier: "field-song-title",
                accessibilityLabel: "Song title, song \(position)"
            )
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

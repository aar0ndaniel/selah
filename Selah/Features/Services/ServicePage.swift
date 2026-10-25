import SwiftUI
import SwiftData

/// One recorded service as a full page: its parts (sermons, Bible classes, songs) in the order they happened.
///
/// A new service starts empty with three add buttons. Each part is its own inset grouped section with a native
/// DisclosureGroup row: sermons and Bible classes hold a title, a person, verses and notes; songs hold a type
/// (hymn, chorus, worship), a hymn number for hymns, and a title that links to the song library.
///
/// Pushed in the Services `NavigationStack` (no stack of its own, no sheet). Anything that still wants to present
/// a service in a sheet (Today, Notes) uses `ServiceSheet`, which wraps this page in a stack.
struct ServicePage: View {
    @Bindable var service: Service

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var meetingDays: [MeetingDay]
    @Query private var profiles: [UserProfile]
    @Query(sort: \LibrarySong.title) private var librarySongs: [LibrarySong]

    /// The sermon or class whose "Add verse" opened the verse picker.
    @State private var pickerPart: ServicePart?
    /// True while the gathering type is "Other" and the name is typed by hand.
    @State private var isOther = false
    @State private var didSetUp = false
    @State private var showDatePicker = false
    /// Parts whose disclosure row is open.
    @State private var expanded: Set<PersistentIdentifier>
    @State private var isReordering = false
    @State private var partToDelete: ServicePart?
    @State private var favouriteTaps = 0
    @FocusState private var focus: ServiceField?

    private static let otherTag = "__other__"

    init(service: Service) {
        self._service = Bindable(service)
        let open = service.parts
            .filter { ServicesLogic.partStartsExpanded(kind: $0.kind, hasContent: $0.hasContent) }
            .map { $0.persistentModelID }
        self._expanded = State(initialValue: Set(open))
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

    private var dateText: String {
        service.date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }

    var body: some View {
        let parts = service.orderedParts
        ScrollViewReader { proxy in
            List {
                headerSection
                if isReordering {
                    reorderSection(parts)
                } else {
                    partSections(parts)
                    addSection(proxy: proxy, isEmpty: parts.isEmpty)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(isReordering ? .active : .inactive))
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Service")
            .navigationBarTitleDisplayMode(.inline)
            .hidesPlusButton()
            .toolbar {
                if parts.count > 1 || isReordering {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(isReordering ? "Done" : "Reorder") {
                            focus = nil
                            if reduceMotion {
                                isReordering.toggle()
                            } else {
                                withAnimation { isReordering.toggle() }
                            }
                        }
                        .accessibilityIdentifier("reorder-parts")
                        .accessibilityHint(isReordering ? "Finishes reordering" : "Changes the order of the parts")
                    }
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
            .alert(
                deleteTitle,
                isPresented: Binding(
                    get: { partToDelete != nil },
                    set: { if !$0 { partToDelete = nil } }
                ),
                presenting: partToDelete
            ) { part in
                Button("Delete", role: .destructive) {
                    delete(part)
                    partToDelete = nil
                }
                Button("Cancel", role: .cancel) { partToDelete = nil }
            } message: { part in
                Text(part.kind == .song
                     ? "It will be taken out of this service."
                     : "Its notes and verses will be deleted too.")
            }
            .sensoryFeedback(.impact(weight: .light), trigger: favouriteTaps)
            .onChange(of: focus) { old, _ in
                linkSongIfNeeded(leaving: old)
            }
            .onAppear {
                guard !didSetUp else { return }
                didSetUp = true
                let name = service.gatheringName
                isOther = !name.isEmpty && !gatheringNames.contains(name)
            }
            .onDisappear {
                // A title still being typed when the page closes is linked too.
                for part in service.parts where part.kind == .song {
                    SongLibrary.link(part, in: modelContext)
                }
            }
        }
    }

    private var pickerIsPresented: Binding<Bool> {
        Binding(
            get: { pickerPart != nil },
            set: { if !$0 { pickerPart = nil } }
        )
    }

    private var deleteTitle: String {
        guard let part = partToDelete else { return "Delete this part?" }
        switch part.kind {
        case .sermon: return "Delete this sermon?"
        case .bibleClass: return "Delete this Bible class?"
        case .song: return "Delete this song?"
        }
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
                ServiceLabeledField(
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

    // MARK: Parts
    //
    // Section(isExpanded:) only collapses in a `.sidebar` list (Apple's Section docs), so each part is a native
    // DisclosureGroup: the first row of an inset grouped section, with the content rows inside it.

    @ViewBuilder
    private func partSections(_ parts: [ServicePart]) -> some View {
        ForEach(Array(parts.enumerated()), id: \.element.persistentModelID) { index, part in
            Section {
                DisclosureGroup(isExpanded: expansion(for: part)) {
                    partContent(part, index: index)
                } label: {
                    partLabel(part, index: index, count: parts.count)
                }
            }
        }
    }

    @ViewBuilder
    private func partContent(_ part: ServicePart, index: Int) -> some View {
        switch part.kind {
        case .sermon, .bibleClass:
            ServiceTalkFields(
                part: part,
                index: index,
                focus: $focus,
                onAddVerse: { pickerPart = part }
            )
        case .song:
            ServiceSongFields(
                part: part,
                index: index,
                focus: $focus,
                library: librarySongs,
                onPick: { song in
                    SongLibrary.adopt(song, for: part, in: modelContext)
                    focus = nil
                },
                onTypeChange: { _ = SongLibrary.link(part, in: modelContext) }
            )
        }
    }

    private func expansion(for part: ServicePart) -> Binding<Bool> {
        let id = part.persistentModelID
        return Binding(
            get: { expanded.contains(id) },
            set: { isOpen in
                if isOpen { expanded.insert(id) } else { expanded.remove(id) }
            }
        )
    }

    /// Disclosure row: tile, heading, a one-line summary while closed, and the favourite star for talks.
    /// The whole row (except the star) opens and closes the part; swipe or long-press to delete or move it.
    private func partLabel(_ part: ServicePart, index: Int, count: Int) -> some View {
        let isOpen = expanded.contains(part.persistentModelID)
        let heading = ServicesLogic.partHeading(kind: part.kind, songType: part.songType)
        let summary = Self.summary(of: part)
        return HStack(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.s) {
                TileIcon(icon: Self.icon(for: part.kind), tone: Self.tileTone(for: part.kind))
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(heading)
                        .font(.selahCardTitle)
                        .foregroundStyle(.primary)
                    if !isOpen && !summary.isEmpty {
                        Text(summary)
                            .font(.selahLabel)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { toggle(part) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary.isEmpty ? heading : "\(heading), \(summary)")
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows or hides this part")
            .accessibilityAddTraits([.isHeader, .isButton])
            .accessibilityIdentifier("part-row-\(index)")

            if part.kind != .song {
                Button {
                    part.isFavourite.toggle()
                    favouriteTaps += 1
                } label: {
                    PIconView(.star, filled: part.isFavourite, size: 22)
                        .foregroundStyle(Color.accentColor)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("favourite-part-\(index)")
                .accessibilityLabel(part.kind == .sermon ? "Favourite sermon" : "Favourite Bible class")
                .accessibilityValue(part.isFavourite ? "On" : "Off")
                .accessibilityAddTraits(part.isFavourite ? .isSelected : [])
            }
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                requestDelete(part)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            Button { move(part, by: -1) } label: { Label("Move up", picon: .caretUp) }
                .disabled(ServicesLogic.movedIndex(index, by: -1, count: count) == nil)
            Button { move(part, by: 1) } label: { Label("Move down", picon: .caretDown) }
                .disabled(ServicesLogic.movedIndex(index, by: 1, count: count) == nil)
            Button(role: .destructive) {
                requestDelete(part)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .accessibilityAction(named: "Move up") { move(part, by: -1) }
        .accessibilityAction(named: "Move down") { move(part, by: 1) }
        .accessibilityAction(named: "Delete") { requestDelete(part) }
    }

    private func toggle(_ part: ServicePart) {
        let binding = expansion(for: part)
        if reduceMotion {
            binding.wrappedValue.toggle()
        } else {
            withAnimation(.snappy) { binding.wrappedValue.toggle() }
        }
    }

    // MARK: Reorder

    private func reorderSection(_ parts: [ServicePart]) -> some View {
        Section {
            ForEach(parts) { part in
                HStack(spacing: Theme.Spacing.s) {
                    TileIcon(icon: Self.icon(for: part.kind), tone: Self.tileTone(for: part.kind))
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(ServicesLogic.partHeading(kind: part.kind, songType: part.songType))
                            .font(.selahHeadline)
                        let summary = Self.summary(of: part)
                        if !summary.isEmpty {
                            Text(summary)
                                .font(.selahLabel)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
            .onMove { source, destination in
                reorder(parts, from: source, to: destination)
            }
            .onDelete { offsets in
                for offset in offsets where parts.indices.contains(offset) {
                    requestDelete(parts[offset])
                }
            }
        } footer: {
            Text("Drag the handles to change the order.")
        }
    }

    // MARK: Add

    private func addSection(proxy: ScrollViewProxy, isEmpty: Bool) -> some View {
        Section {
            addButton("Add sermon", kind: .sermon, identifier: "add-part-sermon", proxy: proxy)
            addButton("Add Bible class", kind: .bibleClass, identifier: "add-part-class", proxy: proxy)
            addButton("Add song", kind: .song, identifier: "add-part-song", proxy: proxy)
        } footer: {
            if isEmpty {
                Text("Add each part in the order it happens. Songs you log are kept in your song library.")
            }
        }
    }

    private func addButton(_ title: String, kind: ServicePartKind, identifier: String, proxy: ScrollViewProxy) -> some View {
        Button {
            addPart(kind, proxy: proxy)
        } label: {
            HStack(spacing: Theme.Spacing.s) {
                TileIcon(icon: Self.icon(for: kind), tone: Self.tileTone(for: kind))
                Text(title)
                    .font(.selahBody)
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(identifier)
    }

    private func addPart(_ kind: ServicePartKind, proxy: ScrollViewProxy) {
        let part = ServicePart(kind: kind, order: service.nextPartOrder)
        modelContext.insert(part)
        part.service = service
        // Save now so the row id is the permanent one; a temporary id would change on autosave and drop the focus.
        try? modelContext.save()
        let id = part.persistentModelID
        expanded.insert(id)
        Task { @MainActor in
            // Let the List lay out the new section before scrolling to it.
            try? await Task.sleep(for: .milliseconds(250))
            if reduceMotion {
                proxy.scrollTo(id, anchor: .top)
            } else {
                withAnimation { proxy.scrollTo(id, anchor: .top) }
            }
            // Songs start as hymns, so the hymn number comes first.
            focus = kind == .song ? ServiceField.hymn(id) : ServiceField.partTitle(id)
        }
    }

    // MARK: Delete and move

    private func requestDelete(_ part: ServicePart) {
        if part.hasContent {
            partToDelete = part
        } else {
            delete(part)
        }
    }

    private func delete(_ part: ServicePart) {
        focus = nil
        SongLibrary.partWillBeDeleted(part, in: modelContext)
        expanded.remove(part.persistentModelID)
        let remaining = service.orderedParts.filter { $0 !== part }
        modelContext.delete(part)
        renumber(remaining)
    }

    private func move(_ part: ServicePart, by step: Int) {
        var current = service.orderedParts
        guard let index = current.firstIndex(where: { $0 === part }),
              let target = ServicesLogic.movedIndex(index, by: step, count: current.count) else { return }
        current.swapAt(index, target)
        renumber(current)
    }

    private func reorder(_ parts: [ServicePart], from source: IndexSet, to destination: Int) {
        let order = ServicesLogic.reorderedIndices(count: parts.count, from: source, to: destination)
        renumber(order.map { parts[$0] })
    }

    private func renumber(_ parts: [ServicePart]) {
        for (index, part) in parts.enumerated() where part.order != index {
            part.order = index
        }
    }

    // MARK: Verses

    private func addVerse(_ ref: VerseRef) {
        guard let part = pickerPart else { return }
        ref.part = part.kind == .bibleClass ? .bibleClass : .sermon
        modelContext.insert(ref)
        ref.servicePart = part
    }

    // MARK: Song library

    /// Leaving a song's title or hymn number links it to the song library.
    private func linkSongIfNeeded(leaving field: ServiceField?) {
        guard let field else { return }
        let id: PersistentIdentifier
        switch field {
        case .partTitle(let partID), .hymn(let partID): id = partID
        default: return
        }
        guard let part = service.parts.first(where: { $0.persistentModelID == id }), part.kind == .song else { return }
        SongLibrary.link(part, in: modelContext)
    }

    // MARK: Look

    static func icon(for kind: ServicePartKind) -> PIcon {
        switch kind {
        case .sermon: return .quotes
        case .bibleClass: return .book
        case .song: return .musicNotes
        }
    }

    static func tileTone(for kind: ServicePartKind) -> TileTone {
        switch kind {
        case .sermon: return .brand
        case .bibleClass: return .sage
        case .song: return .coral
        }
    }

    /// One line under a closed part: "Grace that keeps · Pastor Mensah", or "Hymn 212, Great is thy faithfulness".
    static func summary(of part: ServicePart) -> String {
        let summary = part.summary
        let title = summary.displayTitle
        let person = part.kind == .song ? "" : part.person.trimmingCharacters(in: .whitespacesAndNewlines)
        return [title, person].filter { !$0.isEmpty }.joined(separator: " \u{00B7} ")
    }
}

// MARK: - Fields

/// Which text field has focus on the service page.
enum ServiceField: Hashable {
    case gathering
    case partTitle(PersistentIdentifier)
    case partPerson(PersistentIdentifier)
    case hymn(PersistentIdentifier)
}

/// A text field with a small label above it that stays when the field is filled; the placeholder is an example.
private struct ServiceLabeledField: View {
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
                .font(.selahBody)
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

// MARK: - Sermon and Bible class

/// The rows inside a sermon or Bible class: title, person, verses, notes.
private struct ServiceTalkFields: View {
    @Bindable var part: ServicePart
    let index: Int
    var focus: FocusState<ServiceField?>.Binding
    let onAddVerse: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize

    private var isSermon: Bool { part.kind == .sermon }

    var body: some View {
        ServiceLabeledField(
            label: isSermon ? "Title" : "Lesson",
            placeholder: isSermon ? "e.g. Grace that keeps" : "e.g. Walking in the Spirit",
            text: $part.title,
            field: .partTitle(part.persistentModelID),
            focus: focus,
            axis: .vertical,
            identifier: "field-part-title-\(index)"
        )
        ServiceLabeledField(
            label: isSermon ? "Sermonist" : "Taught by",
            placeholder: isSermon ? "e.g. Pastor Mensah" : "e.g. Deacon Owusu",
            text: $part.person,
            field: .partPerson(part.persistentModelID),
            focus: focus,
            identifier: "field-part-person-\(index)"
        )
        ForEach(part.verses) { verse in
            verseRow(verse)
        }
        Button(action: onAddVerse) {
            PLabel("Add verse", icon: .plus, size: 18)
                .font(.selahBody)
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("add-verse-\(index)")
        .accessibilityHint("Finds a verse to attach")
        RichNoteEditor(
            text: $part.notes,
            owner: .servicePart(part),
            field: .body,
            placeholder: isSermon ? "Sermon message" : "Class notes",
            embedded: true
        )
        .padding(.vertical, Theme.Spacing.xs)
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
                modelContext.delete(verse)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                modelContext.delete(verse)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
    }
}

// MARK: - Song

/// The rows inside a song: type, hymn number (hymns only), title with library suggestions, lyrics link.
private struct ServiceSongFields: View {
    @Bindable var part: ServicePart
    let index: Int
    var focus: FocusState<ServiceField?>.Binding
    let library: [LibrarySong]
    let onPick: (LibrarySong) -> Void
    let onTypeChange: () -> Void

    @Environment(\.modelContext) private var modelContext
    /// Hymnary suggestions for the title (hymns only).
    @State private var lookup = HymnaryLookupModel()

    private var titleFocused: Bool {
        focus.wrappedValue == .partTitle(part.persistentModelID)
    }

    private var suggestions: [LibrarySong] {
        guard titleFocused else { return [] }
        let indices = SongLibraryLogic.suggestions(
            for: part.title,
            preferredType: part.songType,
            in: library.map { $0.key }
        )
        return indices.map { library[$0] }.filter { $0 !== part.librarySong }
    }

    private var typeSelection: Binding<SongType> {
        Binding(
            get: { part.songType },
            set: { newValue in
                guard newValue != part.songType else { return }
                part.songType = newValue
                if newValue != .hymn { lookup.clear() }
                onTypeChange()
            }
        )
    }

    var body: some View {
        Picker("Song type", selection: typeSelection) {
            ForEach(SongType.allCases, id: \.self) { type in
                Text(SongLibraryLogic.shortTypeName(type)).tag(type)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: Theme.minTapTarget)
        .accessibilityIdentifier("song-type-\(index)")

        if part.songType == .hymn {
            ServiceLabeledField(
                label: "Hymn number",
                placeholder: "e.g. 212",
                text: $part.hymnNumber,
                field: .hymn(part.persistentModelID),
                focus: focus,
                keyboard: .numberPad,
                capitalization: .never,
                identifier: "field-hymn-number-\(index)"
            )
        }

        ServiceLabeledField(
            label: "Song title",
            placeholder: "e.g. Great is thy faithfulness",
            text: $part.title,
            field: .partTitle(part.persistentModelID),
            focus: focus,
            capitalization: .sentences,
            identifier: "field-part-title-\(index)"
        )
        .onChange(of: part.title) { _, newValue in
            if part.songType == .hymn, titleFocused { lookup.update(query: newValue) }
        }

        ForEach(Array(suggestions.enumerated()), id: \.element.persistentModelID) { position, song in
            Button {
                onPick(song)
            } label: {
                HStack(spacing: Theme.Spacing.s) {
                    PIconView(.musicNotes, size: 18)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(song.title)
                            .font(.selahBody)
                            .foregroundStyle(.primary)
                        Text(Self.detail(for: song))
                            .font(.selahLabelSmall)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: Theme.minTapTarget)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("song-suggestion-\(index)-\(position)")
            .accessibilityLabel("Use \(song.title), \(Self.detail(for: song))")
        }

        // Local songs first (above), then Hymnary.
        if part.songType == .hymn {
            if titleFocused {
                HymnarySuggestionRows(model: lookup, identifier: "song-\(index)") { pickHymnary($0) }
            }
            HymnaryLyricsStatusRow(status: lookup.lyricsStatus)
        }

        if let song = part.librarySong, song.hasLyrics {
            NavigationLink {
                SongDetailPage(song: song)
            } label: {
                PLabel("Lyrics in your songs", icon: .textAlignLeft, size: 18)
                    .font(.selahBody)
                    .frame(minHeight: Theme.minTapTarget, alignment: .leading)
            }
            .accessibilityIdentifier("song-lyrics-\(index)")
        }
    }

    /// The user picked a Hymnary suggestion: the part takes its title, the song library gets (or finds) the song, and
    /// the lyrics are fetched into it when it has none. Lyrics that were already there are never replaced.
    private func pickHymnary(_ result: HymnarySearchResult) {
        let title = result.suggestedTitle
        part.songType = .hymn
        part.title = title
        lookup.didPick(title: title)
        focus.wrappedValue = nil
        let song = SongLibrary.link(part, in: modelContext)
        if let song, song.hasLyrics {
            if (song.externalID ?? "").isEmpty { song.externalID = result.textAuthNumber }
            lookup.markAlreadyHaveLyrics()
            return
        }
        Task {
            guard let lyrics = await lookup.fetchLyrics(for: result), let song else { return }
            SongLibrary.applyImport(lyrics, externalID: result.textAuthNumber, to: song)
        }
    }

    /// "Hymn 245 · in your songs", "Chorus · in your songs".
    private static func detail(for song: LibrarySong) -> String {
        let type = SongLibraryLogic.typeName(song.songType)
        let number = song.songType == .hymn ? song.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
        let kind = number.isEmpty ? type : "\(type) \(number)"
        return "\(kind) \u{00B7} in your songs"
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
    ServicePagePreview()
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

#Preview("New service") {
    NavigationStack {
        ServicePage(service: Service(date: Date(), gatheringName: "Sunday worship"))
    }
    .modelContainer(SampleData.container)
    .environment(AppRouter())
}

#Preview("Service sheet") {
    ServiceSheet(service: Service(date: Date(), gatheringName: "Sunday worship"))
        .modelContainer(SampleData.container)
        .environment(AppRouter())
}

private struct ServicePagePreview: View {
    @Query(sort: \Service.date, order: .reverse) private var services: [Service]

    var body: some View {
        NavigationStack {
            if let service = services.first {
                ServicePage(service: service)
            } else {
                Text("No sample service")
            }
        }
    }
}

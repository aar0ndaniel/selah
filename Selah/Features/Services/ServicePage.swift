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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var meetingDays: [MeetingDay]
    @Query private var profiles: [UserProfile]

    @State private var pickerPart: VersePart?
    /// True while the gathering type is "Other" and the name is typed by hand.
    @State private var isOther = false
    @State private var didSetUp = false
    @State private var showDatePicker = false
    @State private var sermonOpen: Bool
    @State private var classOpen: Bool

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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                sermonBlock
                Divider()
                classBlock
                Divider()
                songsBlock
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.l)
        }
        .scrollDismissesKeyboard(.interactively)
        .background { AppBackground() }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .hidesPlusButton()
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

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                Text(dateText)
                    .font(.selahDisplay)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Button {
                    showDatePicker = true
                } label: {
                    PIconView(.calendarBlank, size: 22)
                }
                .buttonStyle(.selahSecondary(tone: .slate))
                .accessibilityLabel("Change date")
                .accessibilityHint("Moves this service to another day")
            }

            gatheringMenu

            if isOther {
                TextField("Gathering name", text: $service.gatheringName)
                    .textInputAutocapitalization(.sentences)
                    .modifier(ServiceFieldStyle())
            }
        }
    }

    private var gatheringMenu: some View {
        let tone = ServicesLogic.gatheringTone(gatheringTitle)
        return Menu {
            Picker("Gathering", selection: gatheringSelection) {
                ForEach(gatheringNames, id: \.self) { name in
                    Text(name).tag(name)
                }
                Text("Other").tag(Self.otherTag)
            }
        } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(gatheringTitle)
                    .font(.subheadline.weight(.semibold))
                PIconView(.caretDown, size: 14, relativeTo: .subheadline)
            }
            .foregroundStyle(tone.ink)
            .padding(.horizontal, Theme.Spacing.m)
            .frame(minHeight: Theme.minTapTarget)
            .background(tone.fill, in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel("Gathering, \(gatheringTitle)")
        .accessibilityHint("Changes the type of gathering")
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

    private var sermonBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionHeader(
                title: "Sermon",
                isOpen: sermonOpen,
                toggle: { toggle($sermonOpen) },
                isFavourite: service.sermonFavourite,
                favouriteLabel: "Favourite sermon",
                toggleFavourite: { service.sermonFavourite.toggle() }
            )
            if sermonOpen {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    labelled("Title") {
                        TextField("Sermon title", text: $service.sermonTitle, axis: .vertical)
                            .textInputAutocapitalization(.words)
                            .modifier(ServiceFieldStyle())
                    }
                    labelled("Sermonist") {
                        TextField("Who preached", text: $service.sermonist)
                            .textInputAutocapitalization(.words)
                            .modifier(ServiceFieldStyle())
                    }
                    versesBlock(for: .sermon)
                    labelled("Notes") {
                        noteBox {
                            RichNoteEditor(
                                text: $service.sermonNote,
                                owner: .service(service),
                                field: .sermon,
                                placeholder: "Sermon message",
                                embedded: true
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private var classBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            sectionHeader(
                title: "Bible class",
                isOpen: classOpen,
                toggle: { toggle($classOpen) },
                isFavourite: service.classFavourite,
                favouriteLabel: "Favourite Bible class",
                toggleFavourite: { service.classFavourite.toggle() }
            )
            if classOpen {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    labelled("Lesson") {
                        TextField("Lesson title", text: $service.classLesson, axis: .vertical)
                            .textInputAutocapitalization(.words)
                            .modifier(ServiceFieldStyle())
                    }
                    labelled("Taught by") {
                        TextField("Who taught", text: $service.classTeacher)
                            .textInputAutocapitalization(.words)
                            .modifier(ServiceFieldStyle())
                    }
                    versesBlock(for: .bibleClass)
                    labelled("Notes") {
                        noteBox {
                            RichNoteEditor(
                                text: $service.classNote,
                                owner: .service(service),
                                field: .bibleClass,
                                placeholder: "Class notes",
                                embedded: true
                            )
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }

    private func toggle(_ flag: Binding<Bool>) {
        if reduceMotion {
            flag.wrappedValue.toggle()
        } else {
            withAnimation(.easeOut(duration: 0.2)) { flag.wrappedValue.toggle() }
        }
    }

    /// Section title with a caret that turns, and an icon-only favourite star.
    /// The title and the star are separate buttons, so neither is nested in the other.
    private func sectionHeader(
        title: String,
        isOpen: Bool,
        toggle: @escaping () -> Void,
        isFavourite: Bool,
        favouriteLabel: String,
        toggleFavourite: @escaping () -> Void
    ) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Button(action: toggle) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(.selahTitle)
                        .foregroundStyle(.primary)
                    PIconView(.caretDown, size: 16)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isOpen ? 0 : -90))
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
            .accessibilityHint(isOpen ? "Collapses this section" : "Expands this section")
            .accessibilityAddTraits(.isHeader)

            Button(action: toggleFavourite) {
                PIconView(.star, filled: isFavourite, size: 24)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favouriteLabel)
            .accessibilityValue(isFavourite ? "On" : "Off")
            .accessibilityAddTraits(isFavourite ? .isSelected : [])
        }
    }

    // MARK: Building blocks

    private func labelled<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content()
        }
    }

    private func noteBox<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(Theme.Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
    }

    // MARK: Verses

    private func versesBlock(for part: VersePart) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Verses")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            ForEach(verses(for: part)) { verse in
                verseCard(verse)
            }
            Button {
                pickerPart = part
            } label: {
                PLabel("Add verse", icon: .plus, size: 16, textStyle: .subheadline)
            }
            .buttonStyle(.selahSecondary(tone: .sky))
            .accessibilityHint("Finds a verse to attach")
        }
    }

    private func verseCard(_ verse: VerseRef) -> some View {
        let tone = Tone.sky
        return ToneCard(tone: tone, padding: Theme.Spacing.s) {
            HStack(alignment: .top, spacing: Theme.Spacing.xs) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(verse.reference)
                        .font(.selahHeadline)
                        .foregroundStyle(tone.ink)
                    if !verse.textSnapshot.isEmpty {
                        Text(verse.textSnapshot)
                            .font(.selahVerseCompact)
                            .foregroundStyle(.primary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    deleteVerse(verse)
                } label: {
                    PIconView(.x, size: 16, relativeTo: .body)
                        .foregroundStyle(tone.ink)
                        .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(verse.reference)")
            }
        }
        .accessibilityElement(children: .contain)
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

    private var songsBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("Songs")
                .font(.selahTitle)
                .frame(minHeight: Theme.minTapTarget, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            let songs = sortedSongs
            ForEach(Array(songs.enumerated()), id: \.element.persistentModelID) { index, song in
                SongCard(
                    song: song,
                    position: index + 1,
                    canMoveUp: ServicesLogic.movedIndex(index, by: -1, count: songs.count) != nil,
                    canMoveDown: ServicesLogic.movedIndex(index, by: 1, count: songs.count) != nil,
                    onMove: { step in moveSong(at: index, by: step) },
                    onDelete: { deleteSong(at: index) }
                )
            }

            Button(action: addSong) {
                PLabel("Add song", icon: .musicNotes, size: 16, textStyle: .subheadline)
            }
            .buttonStyle(.selahSecondary(tone: .sage))
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

    private func renumber(_ songs: [Song]) {
        for (index, song) in songs.enumerated() {
            song.order = index
        }
    }
}

// MARK: - Field style

/// Clean full-width text field: filled rounded box, 48pt tall.
private struct ServiceFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.s)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(
                Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
            )
    }
}

// MARK: - Song card

/// One song: hymn number on top (short, number pad), title below at full width, so typing never hides words.
private struct SongCard: View {
    @Bindable var song: Song
    let position: Int
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (Int) -> Void
    let onDelete: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: Theme.Spacing.xs) {
                    TextField("Hymn number", text: $song.hymnNumber)
                        .keyboardType(.numberPad)
                        .frame(
                            maxWidth: typeSize.isAccessibilitySize ? .infinity : 180,
                            minHeight: Theme.minTapTarget,
                            alignment: .leading
                        )
                        .accessibilityLabel("Song \(position) hymn number")
                    Spacer(minLength: 0)
                    Menu {
                        Button {
                            onMove(-1)
                        } label: {
                            Label("Move up", picon: .caretUp)
                        }
                        .disabled(!canMoveUp)
                        Button {
                            onMove(1)
                        } label: {
                            Label("Move down", picon: .caretDown)
                        }
                        .disabled(!canMoveDown)
                        Button(role: .destructive, action: onDelete) {
                            Label("Delete song", picon: .trash)
                        }
                    } label: {
                        PIconView(.dotsThree, size: 22)
                            .foregroundStyle(.secondary)
                            .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Song \(position) options")
                }
                Divider()
                TextField("Song title", text: $song.title)
                    .textInputAutocapitalization(.words)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                    .accessibilityLabel("Song \(position) title")
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

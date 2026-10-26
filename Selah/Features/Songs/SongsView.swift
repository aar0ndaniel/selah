import SwiftUI
import SwiftData

/// The Songs tab: every song logged in a service plus songs added by hand, as cards.
///
/// A to Z (default) groups songs under letters with a letter index at the edge; "Recently logged" and "Most sung"
/// are flat lists. Chips filter by type and the search drawer looks in titles, hymn numbers and lyrics.
/// Songs that are in a service can't be deleted (an alert says how many services).
struct SongsView: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    @Query private var songs: [LibrarySong]

    @State private var query = ""
    @State private var filter: SongsFilter = .all
    @AppStorage("songsSort") private var sortRaw = SongsSort.alphabetical.rawValue
    @State private var openSong: LibrarySong?
    @State private var editingSong: LibrarySong?
    @State private var showNewSong = false
    @State private var practiseSong: LibrarySong?
    @State private var songToDelete: LibrarySong?
    @State private var blockedDelete: (title: String, message: String)?

    private var sort: SongsSort {
        get { SongsSort(rawValue: sortRaw) ?? .alphabetical }
        nonmutating set { sortRaw = newValue.rawValue }
    }

    private var sortBinding: Binding<SongsSort> {
        Binding(get: { sort }, set: { sort = $0 })
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            listPage
                .background { AppBackground() }
                .navigationTitle("Songs")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(item: $openSong) { song in
                    SongDetailPage(song: song)
                }
                .navigationDestination(item: $editingSong) { song in
                    SongEditorPage(song: song)
                }
                .navigationDestination(isPresented: $showNewSong) {
                    SongEditorPage(song: nil)
                }
                .sensoryFeedback(.selection, trigger: sortRaw)
        }
        .fullScreenCover(item: $practiseSong) { song in
            LyricsPracticeView(song: song)
        }
        .confirmationDialog(
            "Delete this song?",
            isPresented: Binding(
                get: { songToDelete != nil },
                set: { if !$0 { songToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: songToDelete
        ) { song in
            Button("Delete song", role: .destructive) {
                SongLibrary.deleteIfUnused(song, in: modelContext)
                songToDelete = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Its lyrics will be deleted too.")
        }
        .alert(
            blockedDelete?.title ?? "",
            isPresented: Binding(
                get: { blockedDelete != nil },
                set: { if !$0 { blockedDelete = nil } }
            )
        ) {
            Button("OK", role: .cancel) { blockedDelete = nil }
        } message: {
            Text(blockedDelete?.message ?? "")
        }
        .onChange(of: router.pendingAction) { _, _ in handlePendingAction() }
        .onAppear { handlePendingAction() }
    }

    // MARK: List

    private var listPage: some View {
        let entries = songs.map { $0.entry }
        let order = SongsLogic.order(entries, sort: sort, filter: filter, query: query)
        let sections = sort == .alphabetical ? SongsLogic.sections(entries, ordered: order) : []
        let showIndex = sort == .alphabetical && sections.count >= 3
        let trailing = showIndex ? Theme.Spacing.xl : Theme.Spacing.m

        return ScrollViewReader { proxy in
            List {
                headerRow(count: order.count)
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.Spacing.m, bottom: 0, trailing: Theme.Spacing.m))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                chips
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if order.isEmpty {
                    emptyState
                        .padding(.top, Theme.Spacing.xl)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                } else if sort == .alphabetical {
                    // A flat list: the letter strip at the edge does the jumping.
                    ForEach(order.map { songs[$0] }) { song in
                        row(for: song, trailing: trailing)
                    }
                } else {
                    ForEach(order.map { songs[$0] }) { song in
                        row(for: song, trailing: trailing)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, Theme.Spacing.plusButtonClearance, for: .scrollContent)
            .overlay(alignment: .trailing) {
                if showIndex {
                    SongsIndexStrip(
                        letters: SongsIndexStrip.alphabet,
                        enabled: Set(sections.map { $0.letter })
                    ) { letter in
                        guard let first = sections.first(where: { $0.letter == letter })?.indices.first else { return }
                        proxy.scrollTo(songs[first].persistentModelID, anchor: .top)
                    }
                    .padding(.trailing, 2)
                }
            }
            .hidesPlusWhileSearching()
        }
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search songs and lyrics"
        )
    }

    private var chips: some View {
        FilterChips(items: SongsFilter.allCases, selection: $filter) { $0.chipTitle }
    }

    /// "12 songs" in the accent colour, and a sort menu on the right.
    private func headerRow(count: Int) -> some View {
        HStack {
            Text(count == 1 ? "1 song" : "\(count) songs")
                .font(.selahLabel)
                .foregroundStyle(Theme.accent)
                .accessibilityIdentifier("songs-count")
            Spacer(minLength: Theme.Spacing.s)
            Menu {
                Picker("Sort songs", selection: sortBinding) {
                    ForEach(SongsSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
            } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(sort.title)
                        .font(.selahLabel)
                    Image(picon: .arrowsDownUp)
                }
                .frame(minHeight: Theme.minTapTarget)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Sort songs")
            .accessibilityValue(sort.title)
            .accessibilityIdentifier("songs-sort")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            ContentUnavailableView.search(text: trimmed)
        } else if songs.isEmpty {
            EmptyState(
                title: "No songs yet",
                icon: .musicNotes,
                message: "Songs you log in a service show up here. You can also add your own.",
                actionTitle: "Add song",
                action: { showNewSong = true }
            )
        } else {
            EmptyState(
                title: "No songs here yet",
                icon: .musicNotes,
                message: "Try another filter, or add a song of your own.",
                actionTitle: "Add song",
                action: { showNewSong = true }
            )
        }
    }

    // MARK: Row

    private func row(for song: LibrarySong, trailing: CGFloat) -> some View {
        Button {
            openSong = song
        } label: {
            SongCard(
                title: song.title,
                type: song.songType,
                hymnNumber: song.hymnNumber,
                hasLyrics: song.hasLyrics
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            SongsLogic.rowAccessibilityLabel(
                title: song.title.isEmpty ? "Untitled song" : song.title,
                type: song.songType,
                hymnNumber: song.hymnNumber,
                timesSung: song.timesSung,
                hasLyrics: song.hasLyrics
            )
        )
        .accessibilityHint("Opens this song")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(song.hasLyrics ? "song-row-lyrics" : "song-row")
        .accessibilityAction(named: "Delete") { requestDelete(song) }
        .listRowInsets(EdgeInsets(top: 6, leading: Theme.Spacing.m, bottom: 6, trailing: trailing))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                requestDelete(song)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
        .contextMenu {
            if song.hasLyrics {
                Button {
                    practiseSong = song
                } label: {
                    Label("Practise", picon: .play)
                }
            }
            Button {
                editingSong = song
            } label: {
                Label("Edit", picon: .pencilSimple)
            }
            Button(role: .destructive) {
                requestDelete(song)
            } label: {
                Label("Delete", picon: .trash)
            }
        }
    }

    // MARK: Actions

    /// A song in a service stays and an alert says why; any other song asks first.
    private func requestDelete(_ song: LibrarySong) {
        switch SongsLogic.deleteDecision(serviceCount: SongLibrary.serviceCount(of: song)) {
        case .allowed:
            songToDelete = song
        case .blocked(let title, let message):
            blockedDelete = (title, message)
        }
    }

    private func handlePendingAction() {
        guard router.pendingAction == .addSong else { return }
        router.pendingAction = nil
        showNewSong = true
    }
}

// MARK: - Letter index

/// The A to Z strip at the right edge, like Contacts. Tap or drag to jump to the first song with that letter.
/// Letters with no songs are dimmed and skipped. Hidden from VoiceOver (it can scroll the list directly).
private struct SongsIndexStrip: View {
    /// "A" to "Z", then "#" when some title starts with a digit or symbol.
    static let alphabet: [String] = (65...90).compactMap { Unicode.Scalar($0).map { String(Character($0)) } }

    let letters: [String]
    let enabled: Set<String>
    let onSelect: (String) -> Void

    @ScaledMetric(relativeTo: .caption) private var scaledSlot: CGFloat = 15
    @State private var current: String?

    private var slot: CGFloat { min(scaledSlot, 18) }

    /// A to Z, plus "#" at the end only if a song needs it.
    private var shownLetters: [String] {
        enabled.contains(SongsLogic.otherLetter) ? letters + [SongsLogic.otherLetter] : letters
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(shownLetters, id: \.self) { letter in
                Text(letter)
                    .font(.selahEyebrow)
                    .foregroundStyle(Theme.accent)
                    .opacity(enabled.contains(letter) ? 1 : 0.3)
                    .frame(width: 24, height: slot)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let position = Int(value.location.y / slot)
                    let list = shownLetters
                    guard list.indices.contains(position) else { return }
                    let letter = list[position]
                    guard enabled.contains(letter), letter != current else { return }
                    current = letter
                    onSelect(letter)
                }
                .onEnded { _ in current = nil }
        )
        .sensoryFeedback(.selection, trigger: current)
        .accessibilityHidden(true)
    }
}

#Preview("Songs") {
    SongsView()
        .environment(AppRouter())
        .modelContainer(SampleData.container)
}

#Preview("Songs, empty") {
    SongsView()
        .environment(AppRouter())
        .modelContainer(SampleData.makeContainer(seeded: false))
}

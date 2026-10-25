import SwiftUI
import SwiftData

/// One song as a full page: title and pills, the lyrics as numbered verses (the refrain after each one), a
/// Practise button, and the services it was sung in.
///
/// Pushed in a `NavigationStack` (the Songs tab, or a service page). Edit opens `SongEditorPage` in the same stack.
struct SongDetailPage: View {
    let song: LibrarySong

    @State private var practising = false
    @State private var editing = false

    private var verses: [String] { SongsLogic.cleanedVerses(song.lyricVerses) }

    private var refrain: String { song.refrain.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var services: [Service] { SongLibrary.services(of: song) }

    private var number: String {
        song.songType == .hymn ? song.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines) : ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                header
                if song.hasLyrics {
                    lyricsSection
                } else {
                    noLyricsCard
                }
                sungInSection
            }
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.top, Theme.Spacing.xs)
            .padding(.bottom, Theme.Spacing.l)
        }
        .background { AppBackground() }
        .navigationTitle("Song")
        .navigationBarTitleDisplayMode(.inline)
        .hidesPlusButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
                    .accessibilityIdentifier("song-edit")
                    .accessibilityHint("Changes the title, type and lyrics")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if song.hasLyrics {
                Button {
                    practising = true
                } label: {
                    Label("Practise", picon: .play)
                }
                .buttonStyle(.selahPrimaryFull)
                .padding(.horizontal, Theme.Spacing.m)
                .padding(.bottom, Theme.Spacing.xs)
                .accessibilityIdentifier("song-practise")
                .accessibilityHint("Shows the lyrics full screen, one verse at a time")
            }
        }
        .navigationDestination(isPresented: $editing) {
            SongEditorPage(song: song)
        }
        .fullScreenCover(isPresented: $practising) {
            LyricsPracticeView(song: song)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text(song.title.isEmpty ? "Untitled song" : song.title)
                .font(.selahDisplay)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            PillFlowLayout(spacing: Theme.Spacing.xs) {
                SelahPill(
                    SongLibraryLogic.typeName(song.songType),
                    icon: .musicNotes,
                    style: .soft(SongsStyle.pillTone(for: song.songType))
                )
                if !number.isEmpty {
                    SelahPill("Hymn \(number)", style: .neutral)
                }
                if song.timesSung > 0 {
                    SelahPill("Sung \(song.timesSung)\u{00D7}", icon: .calendarCheck, style: .neutral)
                }
            }

            if let credit = song.lyricsCredit {
                Text(credit)
                    .font(.selahLabel)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("song-credit")
            }
        }
    }

    // MARK: Lyrics

    private var lyricsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            ForEach(Array(verses.enumerated()), id: \.offset) { offset, verse in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    verseBlock(number: offset + 1, text: verse)
                    if !refrain.isEmpty {
                        refrainBlock
                    }
                }
            }
            if verses.isEmpty && !refrain.isEmpty {
                refrainBlock
            }
        }
    }

    private func verseBlock(number: Int, text: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Verse \(number)")
                .selahEyebrow()
                .accessibilityAddTraits(.isHeader)
            Text(text)
                .font(.selahVerse)
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var refrainBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Refrain")
                .selahEyebrow()
            Text(refrain)
                .font(.selahVerse)
                .italic()
                .lineSpacing(4)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var noLyricsCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("No lyrics yet")
                    .font(.selahCardTitle)
                    .accessibilityAddTraits(.isHeader)
                Text(song.songType == .hymn
                     ? "Add the verses and refrain to practise this hymn or read it any time."
                     : "Add the words to practise this song or read them any time.")
                    .font(.selahBody)
                    .foregroundStyle(.primary.opacity(0.78))
                Button("Add lyrics") { editing = true }
                    .buttonStyle(.selahSecondary())
                    .accessibilityIdentifier("song-add-lyrics")
            }
        }
    }

    // MARK: Sung in

    private var sungInSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            Text("Sung in")
                .selahEyebrow()
                .accessibilityAddTraits(.isHeader)
            if services.isEmpty {
                Text("Not sung in a service yet.")
                    .font(.selahBody)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(services) { service in
                    NavigationLink {
                        ServicePage(service: service)
                    } label: {
                        serviceRow(service)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this service")
                }
            }
        }
    }

    private func serviceRow(_ service: Service) -> some View {
        let date = service.date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
        let name = service.gatheringName.trimmingCharacters(in: .whitespacesAndNewlines)
        return HStack(spacing: Theme.Spacing.s) {
            TileIcon(icon: .church, tone: .brand)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(date)
                    .font(.selahBody)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                if !name.isEmpty {
                    Text(name)
                        .font(.selahLabelSmall)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            PIconView(.caretRight, size: 16, relativeTo: .footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Theme.Spacing.s)
        .frame(minHeight: Theme.minTapTarget)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

extension SongsStyle {
    /// The `Tone` behind a type's pill. Hymn uses rose (the pale red that sits beside the brand tile), chorus sage, worship coral.
    static func pillTone(for type: SongType) -> Tone {
        switch type {
        case .hymn: return .rose
        case .chorus: return .sage
        case .worship: return .coral
        }
    }
}

#Preview("Song detail") {
    NavigationStack {
        SongDetailPreview()
    }
    .environment(AppRouter())
    .modelContainer(SampleData.container)
}

private struct SongDetailPreview: View {
    @Query(sort: \LibrarySong.title) private var songs: [LibrarySong]

    var body: some View {
        if let song = songs.first(where: { $0.hasLyrics }) {
            SongDetailPage(song: song)
        } else {
            Text("No sample song")
        }
    }
}

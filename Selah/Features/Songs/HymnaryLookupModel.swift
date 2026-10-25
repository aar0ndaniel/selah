import SwiftUI
import Observation

/// Drives the "From Hymnary" suggestions under a hymn title field (song editor and service page song parts).
///
/// - `update(query:)` waits 400 ms after the last keystroke, needs at least 3 characters, then searches.
/// - `fetchLyrics(for:)` loads the lyrics of a picked suggestion and reports progress through `lyricsStatus`.
/// - Failures never block: the message says the user can type the lyrics instead.
@MainActor
@Observable
final class HymnaryLookupModel {
    enum LyricsStatus: Equatable {
        case idle
        case loading
        /// Lyrics were found and handed to the caller.
        case filled
        /// The song already has lyrics, so nothing was fetched.
        case alreadyHave
        /// Hymnary has the text but no printing may be displayed.
        case unavailable
        case failed
    }

    static let minimumQueryLength = 3
    static let debounce: Duration = .milliseconds(400)

    private(set) var results: [HymnarySearchResult] = []
    private(set) var isSearching = false
    private(set) var searchFailed = false
    private(set) var lyricsStatus: LyricsStatus = .idle

    @ObservationIgnored private let client: HymnaryClient
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// The title that a picked suggestion put in the field; typing it must not search again.
    @ObservationIgnored private var pickedTitle: String?

    init(client: HymnaryClient = HymnaryClient()) {
        self.client = client
    }

    /// True while there is something to show under the field (a search, results or a failure).
    var hasSuggestionContent: Bool {
        isSearching || searchFailed || !results.isEmpty
    }

    /// Text for the inline message when a search or lyrics fetch failed; nil otherwise.
    var message: String? {
        if searchFailed || lyricsStatus == .failed { return HymnaryError.friendlyMessage }
        return nil
    }

    /// Call whenever the title text changes. Hymns only; for other song types call `clear()`.
    func update(query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let pickedTitle, trimmed == pickedTitle { return }
        pickedTitle = nil
        // Typing a different title makes the last lyrics message stale (but a fetch in progress keeps its spinner).
        if lyricsStatus != .loading { lyricsStatus = .idle }
        guard trimmed.count >= Self.minimumQueryLength else {
            results = []
            isSearching = false
            searchFailed = false
            return
        }
        isSearching = true
        searchFailed = false
        searchTask = Task {
            try? await Task.sleep(for: Self.debounce)
            if Task.isCancelled { return }
            do {
                let found = try await client.search(title: trimmed)
                if Task.isCancelled { return }
                results = found
                searchFailed = false
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                results = []
                searchFailed = true
            }
            isSearching = false
        }
    }

    /// Stops any search and hides the suggestions.
    func clear() {
        searchTask?.cancel()
        results = []
        isSearching = false
        searchFailed = false
    }

    /// The user picked a suggestion: remember the title it filled in so that does not trigger another search.
    func didPick(title: String) {
        searchTask?.cancel()
        pickedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        isSearching = false
        searchFailed = false
    }

    /// The picked song already has lyrics, so none are fetched.
    func markAlreadyHaveLyrics() {
        lyricsStatus = .alreadyHave
    }

    /// Forgets the last lyrics message (a new title is being typed).
    func resetLyricsStatus() {
        lyricsStatus = .idle
    }

    /// Lyrics for a picked suggestion, or nil (with `lyricsStatus` saying why).
    func fetchLyrics(for result: HymnarySearchResult) async -> SongsHymnLyrics? {
        lyricsStatus = .loading
        do {
            if let lyrics = try await client.lyrics(textAuthNumber: result.textAuthNumber) {
                lyricsStatus = .filled
                return lyrics
            }
            lyricsStatus = .unavailable
            return nil
        } catch {
            lyricsStatus = .failed
            return nil
        }
    }
}

// MARK: - Rows

/// The rows shown under a hymn title field: a "From Hymnary" label, a spinner while searching, the suggestions
/// (title, first line and author) and an inline message when Hymnary can't be reached.
///
/// Returns plain rows, so it works inside a `Section` of a `Form` or inside a `DisclosureGroup`.
struct HymnarySuggestionRows: View {
    let model: HymnaryLookupModel
    /// Prefix for accessibility identifiers.
    var identifier: String = "hymnary"
    let onPick: (HymnarySearchResult) -> Void

    var body: some View {
        if model.hasSuggestionContent {
            Text("From Hymnary")
                .selahEyebrow()
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(model.results.enumerated()), id: \.element.id) { position, result in
                Button {
                    onPick(result)
                } label: {
                    HStack(spacing: Theme.Spacing.s) {
                        PIconView(.musicNotes, size: 18)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(result.suggestedTitle)
                                .font(.selahBody)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            if !result.detailLine.isEmpty {
                                Text(result.detailLine)
                                    .font(.selahLabelSmall)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("\(identifier)-suggestion-\(position)")
                .accessibilityLabel("Use \(result.suggestedTitle). \(result.detailLine)")
                .accessibilityHint("Fills the title and gets the lyrics")
            }

            if model.isSearching && model.results.isEmpty {
                HStack(spacing: Theme.Spacing.s) {
                    ProgressView()
                    Text("Searching Hymnary")
                        .font(.selahLabel)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: Theme.minTapTarget)
                .accessibilityElement(children: .combine)
            }

            if model.searchFailed {
                HymnaryMessageRow(text: HymnaryError.friendlyMessage)
            }
        }
    }
}

/// The status line after a suggestion was picked: a spinner while lyrics load, then what happened.
struct HymnaryLyricsStatusRow: View {
    let status: HymnaryLookupModel.LyricsStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: Theme.Spacing.s) {
                ProgressView()
                Text("Getting lyrics")
                    .font(.selahLabel)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: Theme.minTapTarget)
            .accessibilityElement(children: .combine)
        case .filled:
            HymnaryMessageRow(text: "Lyrics from Hymnary.org. Check them before you save.", icon: .check)
        case .alreadyHave:
            HymnaryMessageRow(text: "Kept the lyrics you already have.", icon: .info)
        case .unavailable:
            HymnaryMessageRow(text: "Hymnary has no lyrics we can show for this hymn. You can type them instead.", icon: .info)
        case .failed:
            HymnaryMessageRow(text: HymnaryError.friendlyMessage)
        }
    }
}

/// A small inline note with an icon, in secondary text.
struct HymnaryMessageRow: View {
    let text: String
    var icon: PIcon = .warningCircle

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xs) {
            PIconView(icon, size: 16, relativeTo: .footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            Text(text)
                .font(.selahLabel)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

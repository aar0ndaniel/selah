import Foundation
import SwiftData

/// A song in the song library: every song logged in a service, plus songs added by hand.
///
/// Hymns may carry lyrics: numbered verses (`lyricVerses[0]` is verse 1) and a refrain (chorus) sung after each verse.
@Model
final class LibrarySong {
    var title: String = ""
    var songType: SongType = SongType.hymn
    var hymnNumber: String = ""
    /// Verse texts in order; verse 1 first.
    var lyricVerses: [String] = []
    /// The refrain (chorus) sung after each verse; empty when the song has none.
    var refrain: String = ""
    var source: LibrarySongSource = LibrarySongSource.logged
    /// Identifier from a hymnal lookup, when the song was imported.
    var externalID: String?
    var createdAt: Date = Date()
    /// Date of the latest service this song was logged in.
    var lastSungAt: Date?

    /// Service songs linked to this library song. Deleting the library song keeps them (they just unlink).
    @Relationship(deleteRule: .nullify, inverse: \ServicePart.librarySong)
    var parts: [ServicePart] = []

    init(
        title: String = "",
        songType: SongType = .hymn,
        hymnNumber: String = "",
        lyricVerses: [String] = [],
        refrain: String = "",
        source: LibrarySongSource = .logged,
        externalID: String? = nil,
        createdAt: Date = Date(),
        lastSungAt: Date? = nil
    ) {
        self.title = title
        self.songType = songType
        self.hymnNumber = hymnNumber
        self.lyricVerses = lyricVerses
        self.refrain = refrain
        self.source = source
        self.externalID = externalID
        self.createdAt = createdAt
        self.lastSungAt = lastSungAt
    }

    /// How many times the song was logged in a service.
    var timesSung: Int {
        parts.filter { $0.service != nil }.count
    }

    /// True when the song has any verse or refrain text.
    var hasLyrics: Bool {
        lyricVerses.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            || !refrain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Plain value copy for the pure matching rules in `SongLibraryLogic`.
    var key: SongKey {
        SongKey(title: title, type: songType, hymnNumber: hymnNumber)
    }
}

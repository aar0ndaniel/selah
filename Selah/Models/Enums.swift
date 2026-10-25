import Foundation

enum ReadingStatus: String, Codable, Sendable, CaseIterable {
    case upNext
    case reading
    case done
}

enum VersePart: String, Codable, Sendable, CaseIterable {
    case sermon
    case bibleClass
    case none
}

enum CommentField: String, Codable, Sendable, CaseIterable {
    case sermon
    case bibleClass
    case body
}

enum Appearance: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

enum Translation: String, Codable, Sendable, CaseIterable {
    case kjv
    case asv
    case web
    case bsb
}

/// Sticky-note colours. Never gold, yellow, amber, purple, violet, lavender or indigo.
enum NoteColour: String, Codable, Sendable, CaseIterable {
    case peach
    case sage
    case mint
    case sky
    case rose
    case sand
}

/// What one part of a service is. A service is a list of parts in the order they happened.
enum ServicePartKind: String, Codable, Sendable, CaseIterable {
    case sermon
    case bibleClass
    case song
}

/// The kind of song sung in a service or kept in the song library.
enum SongType: String, Codable, Sendable, CaseIterable {
    case hymn
    case chorus
    case worship
}

/// Where a song in the library came from.
enum LibrarySongSource: String, Codable, Sendable, CaseIterable {
    /// Created when a song was logged in a service.
    case logged
    /// Added by hand on the Songs tab.
    case added
    /// Brought in from a hymnal lookup.
    case imported
}

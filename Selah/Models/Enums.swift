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

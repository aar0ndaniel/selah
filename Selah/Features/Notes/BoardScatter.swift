import Foundation

// Pure rules for the "pinned notes" collage on the Notes tab. No UI, so they are unit-tested.

/// How one note sits on the board. Every value comes from a seeded generator, so the same note always lands the
/// same way (FNV-1a plus SplitMix64, never `hashValue`, which changes on every launch).
struct BoardScatter: Equatable, Sendable {
    enum Attachment: Equatable, Sendable {
        /// A red push-pin at the top edge.
        case pin
        /// A strip of translucent tape across the top edge.
        case tape
        /// A paper-clip on the top corner.
        case clip
    }

    /// Tilt of the whole note in degrees, between -4 and 4 and never nearly flat, so the scatter reads as deliberate.
    var rotation: Double
    /// Nudge from the layout position, in points, between -6 and 6.
    var dx: Double
    var dy: Double
    var attachment: Attachment
    /// Tilt of the tape strip or clip in degrees, between -8 and 8.
    var attachmentAngle: Double
}

/// SplitMix64: a tiny seeded generator.
struct BoardGenerator: Sendable {
    private var state: UInt64

    init(seed: String) {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in seed.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        state = hash
    }

    /// A number from 0 to 1 inclusive.
    mutating func next() -> Double {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z % 100_001) / 100_000
    }

    /// A number between `low` and `high`.
    mutating func next(in low: Double, _ high: Double) -> Double {
        low + next() * (high - low)
    }
}

extension StickyStyle {
    /// The board position of a note for a seed. Pinned notes always get a push-pin.
    static func scatter(seed: String, pinned: Bool = false) -> BoardScatter {
        var generator = BoardGenerator(seed: seed)
        let magnitude = generator.next(in: 1.4, 4.0)
        let rotation = generator.next() < 0.5 ? -magnitude : magnitude
        let dx = generator.next(in: -6, 6)
        let dy = generator.next(in: -6, 6)
        let pick = generator.next()
        let attachment: BoardScatter.Attachment
        if pinned || pick < 0.4 {
            attachment = .pin
        } else if pick < 0.72 {
            attachment = .tape
        } else {
            attachment = .clip
        }
        let angle = generator.next(in: -8, 8)
        return BoardScatter(rotation: rotation, dx: dx, dy: dy, attachment: attachment, attachmentAngle: angle)
    }

    static func scatter(for item: NoteItem) -> BoardScatter {
        scatter(
            seed: "board|\(item.kind.rawValue)|\(item.title)|\(Int(item.date.timeIntervalSince1970))",
            pinned: item.pinned
        )
    }

    /// Items in the order they appear on screen: top to bottom by estimated position, left column first on a tie.
    /// VoiceOver reads the board in this order instead of column by column.
    /// `columnOffsets` is how far each column is pushed down (the staggered right column).
    static func readingOrder(columns: [[Int]], heights: [Double], columnOffsets: [Double] = []) -> [Int] {
        var entries: [(index: Int, top: Double, column: Int)] = []
        for (column, indices) in columns.enumerated() {
            var top = column < columnOffsets.count ? columnOffsets[column] : 0.0
            for index in indices {
                entries.append((index, top, column))
                top += heights[index]
            }
        }
        entries.sort { left, right in
            if left.top != right.top { return left.top < right.top }
            return left.column < right.column
        }
        return entries.map { $0.index }
    }

    /// Whole minutes to read `wordCount` words at about 200 words a minute; at least 1.
    static func readMinutes(wordCount: Int) -> Int {
        max(1, Int((Double(wordCount) / 200).rounded(.up)))
    }
}

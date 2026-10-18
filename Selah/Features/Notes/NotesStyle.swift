import SwiftUI

// Small helpers shared by the note cards, the Notes tab and Today. No sticky-note or board code lives here any more.

// MARK: - Pure helpers

enum NotesStyle {
    /// A calm colour for a book, the same on every launch (a sum of its letters, not `hashValue`).
    /// Sky is left out because the verse of the day uses it.
    static func tone(forBook name: String) -> Tone {
        let pool: [Tone] = [.sage, .coral, .rose, .sand, .slate, .mint]
        var sum = 7
        for scalar in name.unicodeScalars {
            sum = (sum &* 31 &+ Int(scalar.value)) & 0x7fff_ffff
        }
        return pool[sum % pool.count]
    }

    /// Whole minutes to read `wordCount` words at about 200 words a minute; at least 1.
    static func readMinutes(wordCount: Int) -> Int {
        max(1, Int((Double(wordCount) / 200).rounded(.up)))
    }
}

/// How the Notes tab orders its list.
enum NoteSort: String, CaseIterable, Identifiable, Sendable {
    case pinnedFirst, newest, oldest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinnedFirst: return "Pinned first"
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        }
    }

    /// Pinned first: pinned notes (newest first), then the rest (newest first).
    /// Newest and Oldest ignore pinning and go purely by date.
    func apply(_ items: [NoteItem]) -> [NoteItem] {
        switch self {
        case .pinnedFirst:
            let sections = NotesIndex.sections(items)
            return sections.pinned + sections.others
        case .newest:
            return NotesIndex.sorted(items)
        case .oldest:
            return NotesIndex.sorted(items).reversed()
        }
    }
}

// MARK: - Pill on a coloured card

/// A small pill for use on a tone-filled card. Same shape as `Pill`, but its fill is a translucent page colour,
/// because a pill of the card's own tone would disappear into it.
struct OnCardPill: View {
    let text: String
    var icon: PIcon? = nil
    var tone: Tone

    var body: some View {
        HStack(spacing: Theme.Spacing.xxs) {
            if let icon {
                PIconView(icon, size: 14, relativeTo: .footnote)
            }
            Text(text)
                .font(.selahLabelSmall.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(tone.ink)
        .padding(.horizontal, Theme.Spacing.s)
        .padding(.vertical, 6)
        .background(Color(.systemBackground).opacity(0.6), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Display helpers

extension AttributedString {
    /// True when any run carries a highlight.
    var hasHighlight: Bool {
        runs.contains { $0[HighlightIDAttribute.self] != nil }
    }

    /// The first `count` characters, keeping their formatting.
    func snippetPrefix(_ count: Int) -> AttributedString {
        let characters = self.characters
        guard characters.count > count else { return self }
        let end = characters.index(characters.startIndex, offsetBy: count)
        return AttributedString(self[characters.startIndex..<end])
    }
}

extension NoteKind {
    var label: String {
        switch self {
        case .study: return "Study"
        case .service: return "Service"
        case .personal: return "Personal"
        }
    }

    var chipTitle: String {
        switch self {
        case .study: return "Study"
        case .service: return "Services"
        case .personal: return "Personal"
        }
    }

    var icon: PIcon {
        switch self {
        case .study: return .bookOpen
        case .service: return .church
        case .personal: return .userCircle
        }
    }
}

extension NoteItem {
    var displayTitle: String {
        title.isEmpty ? "Untitled note" : title
    }
}

import SwiftUI

/// Semantic tokens. Colours live in the asset catalog (light and dark variants).
/// Never use gold, yellow, amber, purple, violet, lavender or indigo.
enum Theme {
    /// 8pt grid.
    enum Spacing {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let s: CGFloat = 12
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
        /// Bottom content margin so the floating + button never covers content.
        static let plusButtonClearance: CGFloat = 88
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 16
        static let card: CGFloat = 24
    }

    enum Palette {
        static let backgroundTop = Color("BackgroundTop")
        static let backgroundMid = Color("BackgroundMid")
        static let backgroundBottom = Color("BackgroundBottom")
        static let notePeach = Color("NotePeach")
        static let noteSage = Color("NoteSage")
        static let noteMint = Color("NoteMint")
        static let noteSky = Color("NoteSky")
        static let noteRose = Color("NoteRose")
        static let noteSand = Color("NoteSand")
    }
}

extension NoteColour {
    /// Pale fill in light mode, deep muted fill in dark mode. Use `.primary` text on top.
    var color: Color {
        switch self {
        case .peach: return Theme.Palette.notePeach
        case .sage: return Theme.Palette.noteSage
        case .mint: return Theme.Palette.noteMint
        case .sky: return Theme.Palette.noteSky
        case .rose: return Theme.Palette.noteRose
        case .sand: return Theme.Palette.noteSand
        }
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.xs) {
        ForEach(NoteColour.allCases, id: \.self) { colour in
            Text(colour.rawValue.capitalized)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.m)
                .background(colour.color, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
        }
    }
    .padding(Theme.Spacing.m)
}

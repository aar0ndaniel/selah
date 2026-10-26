import SwiftUI

/// A rounded-square tile with the mascot doing something. It replaces the Phosphor glyph tile on note cards, song
/// cards and the next-gathering card.
///
/// Light mode: the user's mascot colour at about 22% over `secondarySystemBackground`. Dark mode: the raised neutral
/// grey (#2C2C2E), like the other tiles, with the mascot keeping its own colours.
/// Static by default (no idle motion), because tiles repeat in lists.
struct MascotTile: View {
    let activity: MascotActivity
    let size: CGFloat
    let animated: Bool

    @AppStorage(MascotMode.storageKey) private var storedMode = MascotMode.standard.rawValue
    @Environment(\.colorScheme) private var colorScheme

    init(activity: MascotActivity, size: CGFloat = 56, animated: Bool = false) {
        self.activity = activity
        self.size = size
        self.animated = animated
    }

    private var mode: MascotMode { MascotMode(storedValue: storedMode) }
    private var radius: CGFloat { size * 0.28 }

    var body: some View {
        MascotView(mode: mode, activity: activity, animated: animated)
            .frame(width: size * 0.86, height: size * 0.86)
            .frame(width: size, height: size)
            .background { tileFill }
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var tileFill: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if colorScheme == .dark {
            shape.fill(Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255))
        } else {
            shape
                .fill(Color(.secondarySystemBackground))
                .overlay { shape.fill(mode.body.opacity(0.22)) }
        }
    }
}

#Preview("Mascot tiles") {
    HStack(spacing: Theme.Spacing.s) {
        ForEach(MascotActivity.allCases, id: \.self) { activity in
            MascotTile(activity: activity, size: 48)
        }
    }
    .padding(Theme.Spacing.m)
}

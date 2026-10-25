import SwiftUI
import SwiftData
import UIKit

extension Font {
    /// Practice-view lyric lines: Space Grotesk 30 bold, scaled like `.title`.
    static var selahLyric: Font {
        .custom(SelahFontFamily.display, size: 30, relativeTo: .title).weight(.bold)
    }

    /// Refrain lines in the practice view: Space Grotesk 26 semibold, scaled like `.title2`.
    static var selahLyricRefrain: Font {
        .custom(SelahFontFamily.display, size: 26, relativeTo: .title2).weight(.semibold)
    }
}

/// Full-screen lyrics for practising a song (docs/UI-REFERENCES.md section 2).
///
/// One solid colour: the accent red in light mode (text `Theme.onAccent`), #1C1C1E in dark mode (white text, accent
/// highlights). The current verse, with its refrain, is bright; the others are dimmed to 35%. Tap or swipe moves to
/// the next or previous verse and the list scrolls to it; the bottom buttons do the same for VoiceOver and Switch
/// Control. With Reduce Motion the move is a crossfade and the scroll jumps. The screen stays awake while it is open.
struct LyricsPracticeView: View {
    let song: LibrarySong

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var index = 0

    private var blocks: [LyricsPracticeBlock] {
        LyricsPracticeLogic.blocks(verses: song.lyricVerses, refrain: song.refrain)
    }

    private var isDark: Bool { colorScheme == .dark }

    /// #1C1C1E in dark mode, the accent in light mode.
    private var background: Color {
        isDark ? Color(red: 28 / 255, green: 28 / 255, blue: 30 / 255) : Theme.accent
    }

    /// Text and icons on the background: white in dark mode, `Theme.onAccent` in light mode.
    private var bright: Color { isDark ? .white : Theme.onAccent }

    /// Small labels (eyebrows, the chip text): accent highlights in dark mode.
    private var highlight: Color { isDark ? Theme.accent : Theme.onAccent }

    private var fade: Animation { .easeInOut(duration: reduceMotion ? 0.25 : 0.4) }

    // MARK: Body

    var body: some View {
        ZStack {
            background
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                topBar
                if blocks.isEmpty {
                    emptyMessage
                } else {
                    lyrics
                    bottomBar
                }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .sensoryFeedback(.selection, trigger: index)
        .accessibilityAction(named: "Next verse") { advance(1) }
        .accessibilityAction(named: "Previous verse") { advance(-1) }
        .accessibilityAction(.escape) { dismiss() }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.s) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(song.title.isEmpty ? "Untitled song" : song.title)
                    .font(Font.selahLabel.weight(.semibold))
                    .foregroundStyle(bright)
                    .lineLimit(2)
                let detail = detailLine
                if !detail.isEmpty {
                    Text(detail)
                        .font(.selahLabelSmall)
                        .foregroundStyle(bright.opacity(0.75))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                dismiss()
            } label: {
                PIconView(.x, size: 20, label: "Close")
                    .foregroundStyle(bright)
                    .frame(width: Theme.minTapTarget, height: Theme.minTapTarget)
                    .background(bright.opacity(0.18), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            .accessibilityIdentifier("lyrics-close")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.s)
    }

    /// "Hymn 245" or "Chorus".
    private var detailLine: String {
        let number = song.hymnNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if song.songType == .hymn, !number.isEmpty { return "Hymn \(number)" }
        return SongLibraryLogic.typeName(song.songType)
    }

    // MARK: Lyrics

    private var lyrics: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { position, block in
                        blockView(block, isCurrent: position == index)
                            .id(position)
                            .opacity(position == index ? 1 : 0.35)
                            .animation(fade, value: index)
                    }
                    // Room under the last verse so it can scroll up to the reading position.
                    Color.clear.frame(height: 360)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, Theme.Spacing.l)
                .padding(.top, Theme.Spacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { advance(1) }
            }
            .scrollIndicators(.hidden)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30).onEnded { value in
                    let across = value.translation.width
                    guard abs(across) > abs(value.translation.height) * 1.5 else { return }
                    advance(across < 0 ? 1 : -1)
                }
            )
            .onChange(of: index) { _, position in
                let anchor = UnitPoint(x: 0.5, y: 0.12)
                if reduceMotion {
                    proxy.scrollTo(position, anchor: anchor)
                } else {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        proxy.scrollTo(position, anchor: anchor)
                    }
                }
            }
        }
    }

    private func blockView(_ block: LyricsPracticeBlock, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            if let number = block.verseNumber {
                eyebrow("Verse \(number)")
                lyricText(block.text, font: .selahLyric)
                if let refrain = block.refrain {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        eyebrow("Refrain")
                        lyricText(refrain, font: .selahLyricRefrain)
                    }
                    .padding(.top, Theme.Spacing.xs)
                }
            } else {
                eyebrow("Refrain")
                lyricText(block.text, font: .selahLyric)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }

    private func eyebrow(_ text: String) -> some View {
        Text(text)
            .font(.selahEyebrow)
            .textCase(.uppercase)
            .tracking(1.0)
            .foregroundStyle(highlight)
    }

    private func lyricText(_ text: String, font: Font) -> some View {
        Text(text)
            .font(font)
            .lineSpacing(6)
            .foregroundStyle(bright)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: Theme.Spacing.m) {
            stepButton(icon: .caretLeft, label: "Previous verse", step: -1, identifier: "lyrics-previous")

            Text(LyricsPracticeLogic.chipText(blocks: blocks, index: index))
                .font(Font.selahLabel.weight(.semibold))
                .foregroundStyle(bright)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minHeight: Theme.minTapTarget)
                .background(bright.opacity(0.18), in: Capsule())
                .contentTransition(.opacity)
                .accessibilityIdentifier("lyrics-chip")

            stepButton(icon: .caretRight, label: "Next verse", step: 1, identifier: "lyrics-next")
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.top, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.s)
    }

    private func stepButton(icon: PIcon, label: String, step: Int, identifier: String) -> some View {
        let target = LyricsPracticeLogic.moved(from: index, by: step, count: blocks.count)
        return Button {
            advance(step)
        } label: {
            PIconView(icon, size: 22, label: label)
                .foregroundStyle(bright)
                .frame(width: 52, height: 52)
                .background(bright.opacity(0.18), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(target == index)
        .opacity(target == index ? 0.35 : 1)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var emptyMessage: some View {
        VStack(spacing: Theme.Spacing.s) {
            Spacer()
            Text("No lyrics to practise")
                .font(.selahTitle)
                .foregroundStyle(bright)
            Text("Add the verses in the song editor, then come back.")
                .font(.selahBody)
                .foregroundStyle(bright.opacity(0.85))
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.l)
        .frame(maxWidth: .infinity)
    }

    // MARK: Moving

    private func advance(_ step: Int) {
        let target = LyricsPracticeLogic.moved(from: index, by: step, count: blocks.count)
        guard target != index else { return }
        index = target
    }
}

#Preview("Practise, light") {
    LyricsPracticeView(song: SampleLyricsSong.make())
}

#Preview("Practise, dark") {
    LyricsPracticeView(song: SampleLyricsSong.make())
        .preferredColorScheme(.dark)
}

/// A song with lyrics for previews.
private enum SampleLyricsSong {
    static func make() -> LibrarySong {
        LibrarySong(
            title: "Blessed assurance",
            songType: .hymn,
            hymnNumber: "245",
            lyricVerses: [
                "Blessed assurance, Jesus is mine!\nO what a foretaste of glory divine!\nHeir of salvation, purchase of God,\nBorn of his Spirit, washed in his blood.",
                "Perfect submission, perfect delight,\nVisions of rapture now burst on my sight;\nAngels descending bring from above\nEchoes of mercy, whispers of love."
            ],
            refrain: "This is my story, this is my song,\nPraising my Saviour all the day long."
        )
    }
}

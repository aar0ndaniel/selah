import SwiftUI

/// A note on the Notes board: a tone-filled paper card with a seeded tilt and nudge and a push-pin, a strip of tape
/// or a paper-clip holding it up. See `BoardScatter` for how the look is chosen.
///
/// The card keeps 24pt of padding above and below its content, so a pin, tape or the corner of the note above can
/// overlap the edge without ever covering a title or a date.
struct BoardNoteCard: View {
    enum Size {
        /// Fills its grid column.
        case regular
        /// Wider, for the pinned row.
        case large
        /// Large type, spanning the full width (a lone pinned note).
        case full
    }

    let item: NoteItem
    var size: Size = .regular
    /// The note's rich text. When it has highlights the snippet shows them (soft mint).
    var richSnippet: AttributedString? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .body) private var largeWidth: CGFloat = 248
    @ScaledMetric(relativeTo: .body) private var minHeight: CGFloat = 120
    @ScaledMetric(relativeTo: .body) private var pinSize: CGFloat = 26
    @ScaledMetric(relativeTo: .body) private var clipSize: CGFloat = 30
    @ScaledMetric(relativeTo: .body) private var tapeWidth: CGFloat = 64
    @ScaledMetric(relativeTo: .body) private var tapeHeight: CGFloat = 22

    private var tone: Tone { item.colour.tone }
    private var scatter: BoardScatter { StickyStyle.scatter(for: item) }

    private var snippetText: Text? {
        if let rich = richSnippet, rich.hasHighlight {
            return Text(rich.snippetPrefix(240).highlightedForDisplay())
        }
        if item.snippet.isEmpty { return nil }
        return Text(item.snippet)
    }

    var body: some View {
        content
            .padding(.horizontal, Theme.Spacing.m)
            .padding(.vertical, Theme.Spacing.l)
            .frame(width: size == .large ? largeWidth : nil, alignment: .topLeading)
            .frame(maxWidth: size == .large ? nil : CGFloat.infinity, minHeight: minHeight, alignment: .topLeading)
            .background {
                // Soft shadow in light mode; a hairline instead on a black page, where a shadow would be invisible.
                shape
                    .fill(tone.fill)
                    .shadow(color: colorScheme == .light ? Color.black.opacity(0.14) : .clear, radius: 7, x: 0, y: 4)
                    .overlay {
                        if colorScheme == .dark {
                            shape.strokeBorder(Color(.separator), lineWidth: 0.5)
                        }
                    }
            }
            .contentShape(shape)
            .overlay(alignment: attachmentAlignment) { attachment }
            .rotationEffect(.degrees(reduceMotion ? 0 : scatter.rotation))
            // Layout is not affected by the nudge, so neighbours may overlap slightly.
            .offset(x: scatter.dx, y: scatter.dy)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SelahPill(item.kind.chipTitle, icon: item.kind.icon, style: .neutral)

            Text(item.displayTitle)
                .font(size != .regular ? .selahCardTitle : .selahHeadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            if let snippetText {
                snippetText
                    .font(size != .regular ? .body : .subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(size != .regular ? 7 : 6)
            }

            Spacer(minLength: 0)

            Text(item.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption)
                .foregroundStyle(tone.inkSecondary)
        }
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
    }

    // MARK: Attachments (decorative, hidden from VoiceOver by the parent button)

    private var attachmentAlignment: Alignment {
        scatter.attachment == .clip ? .topTrailing : .top
    }

    @ViewBuilder
    private var attachment: some View {
        let angle = reduceMotion ? 0 : scatter.attachmentAngle
        switch scatter.attachment {
        case .pin:
            PIconView(.pushPin, filled: true, size: 26, relativeTo: .body)
                .foregroundStyle(Theme.accent)
                .shadow(color: Color.black.opacity(0.3), radius: 1.5, x: 0, y: 1.5)
                .offset(y: -pinSize / 2)
                .accessibilityHidden(true)
        case .tape:
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(Color(.systemGray5).opacity(0.7))
                .overlay {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .strokeBorder(Color(.systemGray3).opacity(0.5), lineWidth: 0.5)
                }
                .frame(width: tapeWidth, height: tapeHeight)
                .rotationEffect(.degrees(angle))
                .offset(y: -tapeHeight / 2)
                .accessibilityHidden(true)
        case .clip:
            BoardAssetIcon(name: "ph-paperclip", size: clipSize)
                .foregroundStyle(Color(.systemGray))
                .rotationEffect(.degrees(angle))
                .offset(x: -Theme.Spacing.l, y: -clipSize / 2)
                .accessibilityHidden(true)
        }
    }
}

/// A bundled Phosphor asset by name, for icons that are not in `PIcon`. Template-tinted, sized in points.
struct BoardAssetIcon: View {
    let name: String
    var size: CGFloat = 24

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview("Board cards") {
    let items = [
        NoteItem(
            id: "a", kind: .service, title: "Sermon on hope", snippet: "Hope is an anchor for the soul, sure and steadfast. We hold it when the sea is rough.",
            date: Date(), colour: .sky, pinned: true, verseRefs: []
        ),
        NoteItem(
            id: "b", kind: .study, title: "Philippians 3 \u{00B7} 12 Oct", snippet: "Pressing on toward the goal.",
            date: Date(), colour: .sage, pinned: false, verseRefs: []
        ),
        NoteItem(
            id: "c", kind: .personal, title: "Prayer list", snippet: "Family, work, the new year.",
            date: Date(), colour: .peach, pinned: false, verseRefs: []
        )
    ]
    ScrollView {
        VStack(spacing: Theme.Spacing.l) {
            ForEach(items) { BoardNoteCard(item: $0) }
            BoardNoteCard(item: items[0], size: .large)
        }
        .padding(Theme.Spacing.l)
    }
}

import SwiftUI

/// Card colour choice: one 44pt swatch per colour with its plain-word name underneath.
/// Selected is shown by a check mark and a thicker ring (not colour alone) and announced to VoiceOver.
struct ToneSwatchPicker: View {
    @Binding var selection: NoteColour

    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 44

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: max(swatchSize + 20, 64)), spacing: Theme.Spacing.xs)],
            alignment: .leading,
            spacing: Theme.Spacing.s
        ) {
            ForEach(NoteColour.allCases, id: \.self) { colour in
                swatch(colour)
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func swatch(_ colour: NoteColour) -> some View {
        let tone = colour.tone
        let isSelected = colour == selection
        return Button {
            selection = colour
        } label: {
            VStack(spacing: Theme.Spacing.xxs) {
                ZStack {
                    Circle().fill(tone.fill)
                    Circle().strokeBorder(tone.ink.opacity(0.35), lineWidth: 1)
                    if isSelected {
                        Circle().strokeBorder(Color.accentColor, lineWidth: 3)
                        PIconView(.check, size: 18)
                            .fontWeight(.bold)
                            .foregroundStyle(tone.ink)
                    }
                }
                .frame(width: swatchSize, height: swatchSize)

                Text(tone.name)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(minWidth: Theme.minTapTarget, minHeight: Theme.minTapTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(tone.name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    @Previewable @State var colour: NoteColour = .sky
    ToneSwatchPicker(selection: $colour)
        .padding(Theme.Spacing.m)
}

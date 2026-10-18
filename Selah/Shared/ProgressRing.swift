import SwiftUI

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 8
    /// Optional tone: the ring is drawn in `tone.ink` on a `tone.fill` track. Default is the accent colour.
    var tone: Tone? = nil
    var centreLabel: String? = nil
    var accessibilityLabel: String = "Progress"
    var accessibilityValue: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clamped: Double { min(max(progress, 0), 1) }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tone?.fill ?? Color.accentColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(tone?.ink ?? Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .smooth, value: clamped)
            if let centreLabel {
                Text(centreLabel)
                    .font(.selahStatSmall)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .padding(lineWidth + Theme.Spacing.xxs)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue ?? "\(Int((clamped * 100).rounded())) percent")
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.l) {
        ProgressRing(
            progress: 0.5,
            centreLabel: "2/4",
            accessibilityLabel: "Chapters read",
            accessibilityValue: "2 of 4 chapters read"
        )
        .frame(width: 72, height: 72)
        ProgressRing(progress: 1, lineWidth: 12)
            .frame(width: 96, height: 96)
    }
    .padding()
}

import SwiftUI

/// A small six-armed snowflake for frozen streak days, drawn as strokes so it scales and takes any colour.
struct SnowflakeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let branch = radius * 0.38
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3 - .pi / 2
            let tip = CGPoint(x: centre.x + radius * cos(angle), y: centre.y + radius * sin(angle))
            path.move(to: centre)
            path.addLine(to: tip)
            // A small V near the tip of each arm.
            let base = CGPoint(
                x: centre.x + radius * 0.6 * cos(angle),
                y: centre.y + radius * 0.6 * sin(angle)
            )
            for side in [-1.0, 1.0] {
                let branchAngle = angle + side * .pi / 4
                path.move(to: base)
                path.addLine(to: CGPoint(
                    x: base.x + branch * cos(branchAngle),
                    y: base.y + branch * sin(branchAngle)
                ))
            }
        }
        return path
    }
}

/// The snowflake as a ready-to-use glyph.
struct SnowflakeIcon: View {
    var size: CGFloat = 14
    var lineWidth: CGFloat = 1.6

    var body: some View {
        SnowflakeShape()
            .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 20) {
        SnowflakeIcon(size: 14)
        SnowflakeIcon(size: 28, lineWidth: 2.4)
    }
    .foregroundStyle(.secondary)
    .padding()
}

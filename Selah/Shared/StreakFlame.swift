import SwiftUI

/// A small burning fire for the streak tile: three layered flame tongues (deep red, coral, pale core) that
/// breathe, sway and flicker at different speeds, plus a few rising embers. Drawn with `Canvas`.
///
/// Colours are reds, coral and orange-red with a near-white core; no yellow or amber. It is meant to sit on a dark
/// badge (see `StreakFlameBadge`), where these colours read in light and dark mode.
///
/// Reduce Motion shows a still flame. Animation pauses when the app is not active or the view is off screen.
struct StreakFlame: View {
    /// True while the streak has just gone up: the flame grows and brightens briefly.
    var flared: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var visible = true

    private var paused: Bool { reduceMotion || !visible || scenePhase != .active }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: paused)) { timeline in
            let time: Double = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                Self.draw(&context, size: size, time: time, showEmbers: !reduceMotion)
            }
        }
        .aspectRatio(0.8, contentMode: .fit)
        .scaleEffect(flared ? 1.3 : 1, anchor: .bottom)
        .brightness(flared ? 0.12 : 0)
        .saturation(flared ? 1.2 : 1)
        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.5), value: flared)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .accessibilityHidden(true)
    }

    // MARK: Drawing

    private struct Layer {
        let widthFactor: CGFloat
        let heightFactor: CGFloat
        let colours: [Color]
        let breathe: Double   // frequency of the size pulse
        let sway: Double      // frequency of the side sway
        let phase: Double
        let swayAmount: CGFloat
    }

    private static let layers: [Layer] = [
        // Outer: deep red.
        Layer(widthFactor: 1.0, heightFactor: 1.0,
              colours: [Color(red: 0.95, green: 0.33, blue: 0.24), Color(red: 0.70, green: 0.15, blue: 0.12)],
              breathe: 5.1, sway: 3.1, phase: 0.0, swayAmount: 0.14),
        // Middle: accent red to coral.
        Layer(widthFactor: 0.72, heightFactor: 0.78,
              colours: [Color(red: 1.0, green: 0.52, blue: 0.38), Color(red: 0.83, green: 0.24, blue: 0.26)],
              breathe: 6.3, sway: 4.3, phase: 1.7, swayAmount: 0.12),
        // Inner: light coral to a near-white core.
        Layer(widthFactor: 0.42, heightFactor: 0.52,
              colours: [Color(red: 1.0, green: 0.68, blue: 0.58), Color(red: 1.0, green: 0.97, blue: 0.94)],
              breathe: 7.7, sway: 5.7, phase: 3.1, swayAmount: 0.09)
    ]

    private static func tongue(in rect: CGRect, sway: CGFloat) -> Path {
        var path = Path()
        let top = rect.minY
        let bottom = rect.maxY
        let width = rect.width
        let height = rect.height
        let tip = CGPoint(x: rect.midX + sway, y: top)
        path.move(to: CGPoint(x: rect.midX, y: bottom))
        path.addCurve(
            to: tip,
            control1: CGPoint(x: rect.minX - width * 0.1, y: bottom),
            control2: CGPoint(x: rect.minX + width * 0.1, y: top + height * 0.5)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: bottom),
            control1: CGPoint(x: rect.maxX - width * 0.1, y: top + height * 0.5),
            control2: CGPoint(x: rect.maxX + width * 0.1, y: bottom)
        )
        path.closeSubpath()
        return path
    }

    private static func draw(_ context: inout GraphicsContext, size: CGSize, time: Double, showEmbers: Bool) {
        let baseWidth = size.width * 0.78
        let baseHeight = size.height * 0.88
        let bottom = size.height
        let centre = size.width / 2

        for layer in layers {
            let pulse: CGFloat = CGFloat(sin(time * layer.breathe + layer.phase))
            let flicker: CGFloat = CGFloat(sin(time * layer.breathe * 2.3 + layer.phase * 1.7))
            let width = baseWidth * layer.widthFactor * (1 + 0.05 * pulse)
            let height = baseHeight * layer.heightFactor * (1 + 0.08 * pulse + 0.04 * flicker)
            let swayNow: CGFloat = CGFloat(sin(time * layer.sway + layer.phase)) + 0.4 * CGFloat(sin(time * layer.sway * 2.7))
            let sway = width * layer.swayAmount * swayNow
            let rect = CGRect(x: centre - width / 2, y: bottom - height, width: width, height: height)
            let path = tongue(in: rect, sway: sway)
            context.fill(
                path,
                with: .linearGradient(
                    Gradient(colors: layer.colours),
                    startPoint: CGPoint(x: centre, y: rect.minY),
                    endPoint: CGPoint(x: centre, y: rect.maxY)
                )
            )
        }

        guard showEmbers else { return }
        for index in 0..<3 {
            let seed = Double(index)
            let raw = time * 0.55 + seed / 3.0
            let progress = CGFloat(raw - raw.rounded(.down))
            let x = centre + CGFloat(sin(time * 2.0 + seed * 2.1)) * size.width * 0.22
            let y = bottom - baseHeight * 0.6 - progress * size.height * 0.4
            let radius: CGFloat = 1.8 * (1 - progress * 0.5)
            let dot = Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
            context.fill(dot, with: .color(Color(red: 1.0, green: 0.55, blue: 0.42).opacity(Double(1 - progress) * 0.9)))
        }
    }
}

/// The flame on a small round dark badge. A dark disc keeps the red flame readable on the red (Study) and green
/// (Service) tiles, in light and dark mode alike.
struct StreakFlameBadge: View {
    var flared: Bool = false

    @ScaledMetric(relativeTo: .title) private var badge: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(Color(red: 0.11, green: 0.11, blue: 0.118))
            StreakFlame(flared: flared)
                .frame(height: badge * 0.68)
                .offset(y: -badge * 0.03)
        }
        .frame(width: badge, height: badge)
        .accessibilityHidden(true)
    }
}

#Preview("Flame") {
    HStack(spacing: 24) {
        StreakFlameBadge()
        StreakFlameBadge(flared: true)
    }
    .padding()
}

import SwiftUI
import UIKit

/// The Selah mascot, drawn in code: a soft plush cloud blob with two big glossy eyes.
///
/// - `mode` nil means the user's chosen colour (`@AppStorage("mascotMode")`).
/// - `mood` changes the face (eyes, brows, mouth, little extras).
/// - `activity` adds a simple accessory (headset, book, hands, pencil, arm, "z").
/// - It scales to the smaller side of its frame, so always give it a frame. It is square artwork.
/// - Decorative by default (hidden from VoiceOver); pass `accessibilityLabel` when it carries meaning.
/// - Idle motion (a slow breathing scale and an occasional blink) stops under Reduce Motion, when `animated` is
///   false and in UI-test launches.
/// - If the asset catalog holds a delivered image with the matching name (see `MascotImages`), that image is shown
///   instead of the drawing.
struct MascotView: View {
    private let mode: MascotMode?
    private let mood: MascotMood?
    private let activity: MascotActivity
    private let animated: Bool
    private let label: String?

    @AppStorage(MascotMode.storageKey) private var storedMode = MascotMode.standard.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false
    @State private var blinking = false
    @State private var waveUp = false

    init(
        mode: MascotMode? = nil,
        mood: MascotMood? = nil,
        activity: MascotActivity = .neutral,
        animated: Bool = true,
        accessibilityLabel: String? = nil
    ) {
        self.mode = mode
        self.mood = mood
        self.activity = activity
        self.animated = animated
        self.label = accessibilityLabel
    }

    private var motionOn: Bool { animated && !reduceMotion && MascotMotion.allowed }

    var body: some View {
        let resolved = mode ?? MascotMode(storedValue: storedMode)
        GeometryReader { proxy in
            let side = max(min(proxy.size.width, proxy.size.height), 0)
            artwork(resolved, side: side)
                .scaleEffect(breathing ? 1.02 : 1, anchor: .bottom)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: motionOn) {
            await runIdleMotion()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "")
        .accessibilityAddTraits(.isImage)
        .accessibilityHidden(label == nil)
    }

    @ViewBuilder
    private func artwork(_ resolved: MascotMode, side: CGFloat) -> some View {
        if let image = MascotImages.image(activity: activity, mood: mood, mode: resolved) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            MascotArtwork(
                mode: resolved,
                mood: mood,
                activity: activity,
                side: side,
                blinking: blinking,
                waveUp: waveUp
            )
        }
    }

    private func runIdleMotion() async {
        guard motionOn else {
            breathing = false
            blinking = false
            waveUp = false
            return
        }
        withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
            breathing = true
        }
        if activity == .waving {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                waveUp = true
            }
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.4...5.2)))
            if Task.isCancelled { break }
            withAnimation(.easeInOut(duration: 0.07)) { blinking = true }
            try? await Task.sleep(for: .milliseconds(110))
            withAnimation(.easeInOut(duration: 0.09)) { blinking = false }
        }
    }
}

// MARK: - Drawing

/// The whole character in a square of `side` points. Every size is a fraction of `side`.
private struct MascotArtwork: View {
    let mode: MascotMode
    let mood: MascotMood?
    let activity: MascotActivity
    let side: CGFloat
    var blinking = false
    var waveUp = false

    private var eyeStyle: MascotEyeStyle {
        if activity == .sleeping { return .closedCurve }
        return mood?.eyes ?? .open
    }

    private var browStyle: MascotBrowStyle { mood?.brows ?? .none }
    private var mouthStyle: MascotMouthStyle { mood?.mouth ?? .none }
    private var extra: MascotExtra { mood?.extra ?? .none }

    private func at(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * side, y: y * side)
    }

    var body: some View {
        ZStack {
            contactShadow
            bodyFill
            bodyShading
            face
            accessory
        }
        .frame(width: side, height: side)
    }

    // MARK: Body

    private var contactShadow: some View {
        Ellipse()
            .fill(Color.black.opacity(0.12))
            .frame(width: side * 0.58, height: side * 0.07)
            .blur(radius: side * 0.02)
            .position(at(0.5, 0.93))
    }

    private var bodyFill: some View {
        MascotBodyShape()
            .fill(
                RadialGradient(
                    colors: [mode.body, mode.bodyDeep],
                    center: UnitPoint(x: 0.35, y: 0.22),
                    startRadius: 0,
                    endRadius: side * 0.95
                )
            )
            .frame(width: side, height: side)
    }

    /// Soft shading, blush and a glossy highlight, all clipped to the body outline.
    private var bodyShading: some View {
        ZStack {
            LinearGradient(
                colors: [Color.clear, mode.bodyDeep.opacity(0.4)],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
            Ellipse()
                .fill(mode.blush.opacity(0.7))
                .frame(width: side * 0.62, height: side * 0.26)
                .blur(radius: side * 0.06)
                .position(at(0.5, 0.78))
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: side * 0.30, height: side * 0.15)
                .rotationEffect(.degrees(-24))
                .blur(radius: side * 0.035)
                .position(at(0.31, 0.2))
        }
        .frame(width: side, height: side)
        .mask { MascotBodyShape() }
    }

    // MARK: Face

    private var face: some View {
        ZStack {
            cheekExtras
            ForEach([CGFloat(0.375), CGFloat(0.625)], id: \.self) { x in
                MascotEyeView(style: eyeStyle, side: side, blinking: blinking)
                    .position(at(x, 0.43))
            }
            brows
            mouth
            otherExtras
        }
        .frame(width: side, height: side)
    }

    /// Cheek colour behind the eyes: rosy cheeks (joyful), a flushed face (angry).
    @ViewBuilder
    private var cheekExtras: some View {
        if extra == .cheeks || extra == .flush {
            let colour = extra == .flush ? Color(red: 0.92, green: 0.30, blue: 0.28) : mode.blush
            let opacity: Double = extra == .flush ? 0.45 : 0.6
            ForEach([CGFloat(0.25), CGFloat(0.75)], id: \.self) { x in
                Ellipse()
                    .fill(colour.opacity(opacity))
                    .frame(width: side * 0.15, height: side * 0.085)
                    .blur(radius: side * 0.012)
                    .position(at(x, 0.56))
            }
        }
    }

    @ViewBuilder
    private var otherExtras: some View {
        switch extra {
        case .none, .cheeks, .flush:
            EmptyView()
        case .hearts:
            ForEach([CGFloat(0.25), CGFloat(0.75)], id: \.self) { x in
                MascotHeartShape()
                    .fill(MascotPalette.heart)
                    .frame(width: side * 0.075, height: side * 0.07)
                    .position(at(x, 0.60))
            }
        case .sparkle:
            MascotSparkleShape()
                .fill(Color.white)
                .shadow(color: mode.bodyDeep.opacity(0.7), radius: side * 0.006)
                .frame(width: side * 0.085, height: side * 0.085)
                .position(at(0.74, 0.58))
            MascotSparkleShape()
                .fill(Color.white.opacity(0.9))
                .shadow(color: mode.bodyDeep.opacity(0.7), radius: side * 0.005)
                .frame(width: side * 0.045, height: side * 0.045)
                .position(at(0.80, 0.52))
        case .sleepyZ:
            if activity != .sleeping {
                Text("z")
                    .font(.system(size: side * 0.11, weight: .bold, design: .rounded))
                    .foregroundStyle(MascotPalette.graphite.opacity(0.55))
                    .position(at(0.82, 0.15))
            }
        case .tear:
            MascotDropShape()
                .fill(MascotPalette.droplet)
                .frame(width: side * 0.04, height: side * 0.06)
                .position(at(0.335, 0.585))
        case .sweat:
            MascotDropShape()
                .fill(MascotPalette.droplet)
                .frame(width: side * 0.045, height: side * 0.07)
                .position(at(0.80, 0.27))
        }
    }

    @ViewBuilder
    private var brows: some View {
        if browStyle != .none {
            // Left brow: a positive angle turns it clockwise (outer end up, inner end down: angry). A negative angle
            // raises the inner end (sad, worried). The right brow mirrors it.
            let angle: Double = {
                switch browStyle {
                case .sad: return -16
                case .worried: return -12
                case .angry: return 20
                case .none: return 0
                }
            }()
            let y: CGFloat = browStyle == .angry ? 0.325 : (browStyle == .worried ? 0.275 : 0.305)
            let length: CGFloat = browStyle == .worried ? 0.11 : 0.10
            Capsule()
                .fill(MascotPalette.ink)
                .frame(width: side * length, height: side * 0.024)
                .rotationEffect(.degrees(angle))
                .position(at(0.375, y))
            Capsule()
                .fill(MascotPalette.ink)
                .frame(width: side * length, height: side * 0.024)
                .rotationEffect(.degrees(-angle))
                .position(at(0.625, y))
        }
    }

    @ViewBuilder
    private var mouth: some View {
        let stroke = StrokeStyle(lineWidth: side * 0.024, lineCap: .round, lineJoin: .round)
        switch mouthStyle {
        case .none:
            EmptyView()
        case .smile:
            MascotArcShape(up: false)
                .stroke(MascotPalette.ink, style: stroke)
                .frame(width: side * 0.13, height: side * 0.04)
                .position(at(0.5, 0.585))
        case .smallSmile:
            MascotArcShape(up: false)
                .stroke(MascotPalette.ink, style: stroke)
                .frame(width: side * 0.08, height: side * 0.026)
                .position(at(0.5, 0.585))
        case .frown:
            MascotArcShape(up: true)
                .stroke(MascotPalette.ink, style: stroke)
                .frame(width: side * 0.09, height: side * 0.03)
                .position(at(0.5, 0.6))
        case .tightFrown:
            MascotArcShape(up: true)
                .stroke(MascotPalette.ink, style: StrokeStyle(lineWidth: side * 0.028, lineCap: .round))
                .frame(width: side * 0.07, height: side * 0.016)
                .position(at(0.5, 0.6))
        case .wobble:
            MascotWobbleShape()
                .stroke(MascotPalette.ink, style: stroke)
                .frame(width: side * 0.12, height: side * 0.03)
                .position(at(0.5, 0.595))
        case .wideOpen:
            MascotOpenMouthShape()
                .fill(MascotPalette.ink)
                .frame(width: side * 0.15, height: side * 0.075)
                .position(at(0.5, 0.565))
        case .flat:
            Ellipse()
                .fill(MascotPalette.ink)
                .frame(width: side * 0.06, height: side * 0.03)
                .position(at(0.5, 0.595))
        }
    }

    // MARK: Accessories

    @ViewBuilder
    private var accessory: some View {
        switch activity {
        case .neutral: EmptyView()
        case .headset: headset
        case .reading: book
        case .praying: hands
        case .writing: pencil
        case .waving: arm
        case .sleeping: sleepingZ
        }
    }

    private var handFill: LinearGradient {
        LinearGradient(colors: [mode.body, mode.bodyDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var headset: some View {
        ZStack {
            MascotBandShape()
                .stroke(MascotPalette.graphite, style: StrokeStyle(lineWidth: side * 0.035, lineCap: .round))
                .frame(width: side * 0.8, height: side * 0.35)
                .position(at(0.5, 0.205))
            ForEach([CGFloat(0.09), CGFloat(0.91)], id: \.self) { x in
                ZStack {
                    RoundedRectangle(cornerRadius: side * 0.04, style: .continuous)
                        .fill(MascotPalette.graphite)
                        .frame(width: side * 0.1, height: side * 0.2)
                    RoundedRectangle(cornerRadius: side * 0.02, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(width: side * 0.045, height: side * 0.12)
                }
                .position(at(x, 0.45))
            }
        }
        .frame(width: side, height: side)
    }

    private var book: some View {
        ZStack {
            RoundedRectangle(cornerRadius: side * 0.02, style: .continuous)
                .fill(MascotPalette.graphite)
                .frame(width: side * 0.56, height: side * 0.2)
                .position(at(0.5, 0.775))
            RoundedRectangle(cornerRadius: side * 0.015, style: .continuous)
                .fill(Color.white)
                .frame(width: side * 0.26, height: side * 0.17)
                .rotationEffect(.degrees(-4))
                .position(at(0.37, 0.77))
            RoundedRectangle(cornerRadius: side * 0.015, style: .continuous)
                .fill(Color.white)
                .frame(width: side * 0.26, height: side * 0.17)
                .rotationEffect(.degrees(4))
                .position(at(0.63, 0.77))
            Rectangle()
                .fill(MascotPalette.graphite.opacity(0.45))
                .frame(width: side * 0.008, height: side * 0.17)
                .position(at(0.5, 0.77))
            ForEach([CGFloat(0.37), CGFloat(0.63)], id: \.self) { x in
                VStack(spacing: side * 0.02) {
                    Capsule().fill(Color(white: 0.82)).frame(width: side * 0.16, height: side * 0.012)
                    Capsule().fill(Color(white: 0.82)).frame(width: side * 0.12, height: side * 0.012)
                    Capsule().fill(Color(white: 0.82)).frame(width: side * 0.14, height: side * 0.012)
                }
                .position(at(x, 0.77))
            }
            ForEach([CGFloat(0.2), CGFloat(0.8)], id: \.self) { x in
                Ellipse()
                    .fill(handFill)
                    .overlay(Ellipse().stroke(Color.white.opacity(0.7), lineWidth: side * 0.008))
                    .frame(width: side * 0.08, height: side * 0.1)
                    .position(at(x, 0.78))
            }
        }
        .frame(width: side, height: side)
    }

    private var hands: some View {
        ZStack {
            Ellipse()
                .fill(handFill)
                .overlay(Ellipse().stroke(Color.white.opacity(0.75), lineWidth: side * 0.009))
                .frame(width: side * 0.10, height: side * 0.22)
                .rotationEffect(.degrees(14))
                .shadow(color: Color.black.opacity(0.12), radius: side * 0.01, y: side * 0.006)
                .position(at(0.475, 0.74))
            Ellipse()
                .fill(handFill)
                .overlay(Ellipse().stroke(Color.white.opacity(0.75), lineWidth: side * 0.009))
                .frame(width: side * 0.10, height: side * 0.22)
                .rotationEffect(.degrees(-14))
                .shadow(color: Color.black.opacity(0.12), radius: side * 0.01, y: side * 0.006)
                .position(at(0.525, 0.74))
        }
        .frame(width: side, height: side)
    }

    private var pencil: some View {
        HStack(spacing: 0) {
            MascotTipShape()
                .fill(MascotPalette.graphite)
                .frame(width: side * 0.06, height: side * 0.05)
            Rectangle()
                .fill(Color.white)
                .overlay(Rectangle().stroke(MascotPalette.graphite.opacity(0.5), lineWidth: side * 0.006))
                .frame(width: side * 0.2, height: side * 0.05)
            Rectangle()
                .fill(MascotPalette.graphite)
                .frame(width: side * 0.025, height: side * 0.05)
            RoundedRectangle(cornerRadius: side * 0.012, style: .continuous)
                .fill(mode.blush)
                .frame(width: side * 0.04, height: side * 0.05)
        }
        .rotationEffect(.degrees(-38))
        .position(at(0.74, 0.74))
        .frame(width: side, height: side)
    }

    private var arm: some View {
        Ellipse()
            .fill(handFill)
            .overlay(Ellipse().stroke(Color.white.opacity(0.7), lineWidth: side * 0.009))
            .frame(width: side * 0.15, height: side * 0.27)
            .rotationEffect(.degrees(waveUp ? 28 : 12), anchor: .bottom)
            .position(at(0.89, 0.40))
            .frame(width: side, height: side)
    }

    private var sleepingZ: some View {
        ZStack {
            Text("z")
                .font(.system(size: side * 0.13, weight: .bold, design: .rounded))
                .foregroundStyle(MascotPalette.graphite)
                .position(at(0.80, 0.16))
            Text("z")
                .font(.system(size: side * 0.08, weight: .bold, design: .rounded))
                .foregroundStyle(MascotPalette.graphite.opacity(0.8))
                .position(at(0.90, 0.05))
        }
        .frame(width: side, height: side)
    }
}

/// One eye in a frame centred on its position.
private struct MascotEyeView: View {
    let style: MascotEyeStyle
    let side: CGFloat
    let blinking: Bool

    private var width: CGFloat { side * 0.118 }
    private var height: CGFloat { side * 0.17 }

    var body: some View {
        eye
            .frame(width: width * 1.5, height: height * 1.3)
    }

    @ViewBuilder
    private var eye: some View {
        switch style {
        case .open:
            oval(widthScale: 1, heightScale: 1, visible: 1)
        case .bigOpen:
            oval(widthScale: 1.18, heightScale: 1.18, visible: 1)
        case .softHalf:
            oval(widthScale: 1.05, heightScale: 1, visible: 0.7, shine: true)
        case .heavyLid:
            oval(widthScale: 1.05, heightScale: 1, visible: 0.45)
                .overlay {
                    // A lid line along the flat top of the visible part.
                    Capsule()
                        .fill(MascotPalette.ink)
                        .frame(width: width * 1.25, height: side * 0.014)
                        .offset(y: height * 0.05)
                }
        case .narrow:
            oval(widthScale: 1.1, heightScale: 0.55, visible: 1)
        case .lookDown:
            sclera(widthScale: 1, heightScale: 1, pupilScale: 0.72, pupilOffset: 0.2)
        case .wide:
            sclera(widthScale: 1.2, heightScale: 1.2, pupilScale: 0.3, pupilOffset: 0)
        case .happyArc:
            MascotArcShape(up: true)
                .stroke(MascotPalette.ink, style: StrokeStyle(lineWidth: side * 0.03, lineCap: .round))
                .frame(width: width * 1.1, height: height * 0.3)
        case .closedCurve:
            MascotArcShape(up: false)
                .stroke(MascotPalette.ink, style: StrokeStyle(lineWidth: side * 0.03, lineCap: .round))
                .frame(width: width * 1.1, height: height * 0.3)
        }
    }

    /// A glossy black oval with a white specular dot. `visible` is the share of the oval's height that shows from
    /// the bottom (1 = fully open).
    private func oval(widthScale: CGFloat, heightScale: CGFloat, visible: CGFloat, shine: Bool = false) -> some View {
        let w = width * widthScale
        let h = height * heightScale
        return ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.17, green: 0.17, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.07)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .fill(Color.white)
                .frame(width: w * 0.4, height: w * 0.4)
                .offset(x: w * 0.16, y: visible < 1 ? h * 0.08 : -h * 0.22)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: w * 0.17, height: w * 0.17)
                .offset(x: -w * 0.2, y: h * 0.24)
            if shine {
                Circle()
                    .fill(Color.white.opacity(0.85))
                    .frame(width: w * 0.12, height: w * 0.12)
                    .offset(x: -w * 0.05, y: h * 0.18)
            }
        }
        .frame(width: w, height: h)
        .mask(alignment: .bottom) {
            Rectangle().frame(height: h * visible)
        }
        .scaleEffect(y: blinking ? 0.08 : 1, anchor: .center)
    }

    /// A white eye with a dark pupil. `pupilOffset` is a share of the eye's height (positive moves the pupil down).
    private func sclera(widthScale: CGFloat, heightScale: CGFloat, pupilScale: CGFloat, pupilOffset: CGFloat) -> some View {
        let w = width * widthScale
        let h = height * heightScale
        let pupil = w * pupilScale
        return ZStack {
            Ellipse()
                .fill(Color.white)
                .overlay(Ellipse().stroke(MascotPalette.ink.opacity(0.85), lineWidth: side * 0.008))
            Circle()
                .fill(MascotPalette.ink)
                .frame(width: pupil, height: pupil)
                .offset(y: h * pupilOffset)
            Circle()
                .fill(Color.white)
                .frame(width: pupil * 0.3, height: pupil * 0.3)
                .offset(x: pupil * 0.14, y: h * pupilOffset - pupil * 0.16)
        }
        .frame(width: w, height: h)
        .scaleEffect(y: blinking ? 0.08 : 1, anchor: .center)
    }
}

// MARK: - Shapes

/// The cloud body: a union of overlapping circles and ellipses, in unit coordinates.
private struct MascotBodyShape: Shape {
    /// x, y, width, height as fractions of the square.
    private static let lobes: [CGRect] = [
        CGRect(x: 0.16, y: 0.20, width: 0.68, height: 0.62),
        CGRect(x: 0.14, y: 0.08, width: 0.40, height: 0.40),
        CGRect(x: 0.47, y: 0.11, width: 0.38, height: 0.38),
        CGRect(x: 0.03, y: 0.35, width: 0.34, height: 0.34),
        CGRect(x: 0.63, y: 0.35, width: 0.34, height: 0.34),
        CGRect(x: 0.14, y: 0.54, width: 0.36, height: 0.36),
        CGRect(x: 0.50, y: 0.54, width: 0.36, height: 0.36)
    ]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for lobe in Self.lobes {
            path.addEllipse(in: CGRect(
                x: rect.minX + lobe.minX * rect.width,
                y: rect.minY + lobe.minY * rect.height,
                width: lobe.width * rect.width,
                height: lobe.height * rect.height
            ))
        }
        return path
    }
}

/// A single curved line: `up` bows upwards (a happy eye, a frown), otherwise downwards (a smile, a relaxed eye).
private struct MascotArcShape: Shape {
    var up: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        if up {
            path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY),
                control: CGPoint(x: rect.midX, y: rect.minY - rect.height)
            )
        } else {
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rect.midX, y: rect.maxY + rect.height)
            )
        }
        return path
    }
}

/// A small wavy line for an anxious mouth.
private struct MascotWobbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let segments = 4
        let step = rect.width / CGFloat(segments)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        for index in 0..<segments {
            let startX = rect.minX + step * CGFloat(index)
            let controlY = index % 2 == 0 ? rect.minY - rect.height * 0.5 : rect.maxY + rect.height * 0.5
            path.addQuadCurve(
                to: CGPoint(x: startX + step, y: rect.midY),
                control: CGPoint(x: startX + step / 2, y: controlY)
            )
        }
        return path
    }
}

/// A small bowl-shaped open smile.
private struct MascotOpenMouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.minY + rect.height * 2)
        )
        path.closeSubpath()
        return path
    }
}

private struct MascotHeartShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + h))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + 0.3 * h),
            control1: CGPoint(x: rect.minX + 0.15 * w, y: rect.minY + 0.8 * h),
            control2: CGPoint(x: rect.minX, y: rect.minY + 0.55 * h)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + 0.22 * h),
            control1: CGPoint(x: rect.minX, y: rect.minY + 0.02 * h),
            control2: CGPoint(x: rect.minX + 0.42 * w, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + w, y: rect.minY + 0.3 * h),
            control1: CGPoint(x: rect.minX + 0.58 * w, y: rect.minY),
            control2: CGPoint(x: rect.minX + w, y: rect.minY + 0.02 * h)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX + 0.5 * w, y: rect.minY + h),
            control1: CGPoint(x: rect.minX + w, y: rect.minY + 0.55 * h),
            control2: CGPoint(x: rect.minX + 0.85 * w, y: rect.minY + 0.8 * h)
        )
        path.closeSubpath()
        return path
    }
}

/// A four-point sparkle.
private struct MascotSparkleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: centre)
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: centre)
        path.closeSubpath()
        return path
    }
}

/// The headset band: an arch from lower left over the top to lower right.
private struct MascotBandShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY),
            control1: CGPoint(x: rect.minX, y: rect.minY - rect.height / 3),
            control2: CGPoint(x: rect.maxX, y: rect.minY - rect.height / 3)
        )
        return path
    }
}

/// A pencil tip pointing left.
private struct MascotTipShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// A small drop (a tear, a sweat drop): pointed at the top, round at the bottom.
private struct MascotDropShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX + w * 0.1, y: rect.midY + rect.height * 0.1),
            control2: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY),
            control2: CGPoint(x: rect.minX - w * 0.1, y: rect.midY + rect.height * 0.1)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("Modes and moods") {
    ScrollView {
        Grid(horizontalSpacing: Theme.Spacing.xs, verticalSpacing: Theme.Spacing.xs) {
            ForEach(MascotMode.allCases, id: \.self) { mode in
                GridRow {
                    ForEach([MascotMood.joyful, .peaceful, .tired, .sad, .loved], id: \.self) { mood in
                        MascotView(mode: mode, mood: mood, animated: false)
                            .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
    }
}

#Preview("Activities") {
    ScrollView {
        Grid(horizontalSpacing: Theme.Spacing.xs, verticalSpacing: Theme.Spacing.xs) {
            ForEach(MascotMode.allCases, id: \.self) { mode in
                GridRow {
                    ForEach(MascotActivity.allCases, id: \.self) { activity in
                        MascotView(mode: mode, activity: activity, animated: false)
                            .frame(width: 52, height: 52)
                    }
                }
            }
        }
        .padding(Theme.Spacing.m)
    }
}

#Preview("Large") {
    VStack(spacing: Theme.Spacing.m) {
        MascotView(mood: .grateful)
            .frame(width: 220, height: 220)
        HStack {
            MascotView(activity: .waving).frame(width: 96, height: 96)
            MascotView(activity: .sleeping).frame(width: 96, height: 96)
            MascotView(mood: .anxious).frame(width: 96, height: 96)
        }
    }
    .padding(Theme.Spacing.m)
}

#Preview("All eight moods") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.s), count: 4), spacing: Theme.Spacing.m) {
        ForEach(MascotMood.allCases, id: \.self) { mood in
            VStack(spacing: Theme.Spacing.xxs) {
                MascotView(mood: mood, animated: false)
                    .frame(width: 80, height: 80)
                Text(mood.title).font(.selahLabelSmall)
            }
        }
    }
    .padding(Theme.Spacing.m)
}

import SwiftUI

// MARK: - Paint splash

/// One drop of paint landing in the mix.
struct Splash: Identifiable {
    let id = UUID()
    let color: Color
    /// Varies the splatter pattern from drop to drop.
    let seed = UInt64.random(in: 1...UInt64.max)
}

/// A drop falls into the swatch, then bursts into a ring of droplets.
struct SplashView: View {
    let splash: Splash

    private enum Phase { case falling, landed, burst }
    @State private var phase = Phase.falling

    private struct Droplet {
        let angle: Double
        let distance: CGFloat
        let size: CGFloat
    }

    private var droplets: [Droplet] {
        var rng = SplitMix64(seed: splash.seed)
        return (0..<14).map { i in
            let base = Double(i) / 14 * 2 * .pi
            return Droplet(
                angle: base + Double.random(in: -0.25...0.25, using: &rng),
                distance: CGFloat.random(in: 60...120, using: &rng),
                size: CGFloat.random(in: 7...18, using: &rng)
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // A ripple that shows up even when the paint matches the mix.
                Circle()
                    .stroke(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 40, height: 40)
                    .scaleEffect(phase == .burst ? 3.2 : 0.2)
                    .opacity(phase == .burst ? 0 : (phase == .landed ? 1 : 0))
                    .position(center)

                // The falling drop.
                Teardrop()
                    .fill(splash.color.gradient)
                    .overlay(Teardrop().stroke(.white, lineWidth: 2))
                    .overlay(alignment: .bottomLeading) {
                        Circle().fill(.white.opacity(0.7)).frame(width: 6, height: 6).offset(x: 5, y: -7)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    .frame(width: 26, height: 36)
                    .scaleEffect(phase == .burst ? 0.2 : 1)
                    .opacity(phase == .burst ? 0 : 1)
                    .position(x: center.x, y: phase == .falling ? -20 : center.y)

                // The splat in the middle.
                PaintBlob(seed: splash.seed)
                    .fill(splash.color)
                    .overlay(PaintBlob(seed: splash.seed).stroke(.white.opacity(0.8), lineWidth: 2))
                    .frame(width: 64, height: 64)
                    .scaleEffect(phase == .burst ? 1.5 : 0.01)
                    .opacity(phase == .burst ? 0 : 0.95)
                    .position(center)

                // Droplets flying out.
                ForEach(Array(droplets.enumerated()), id: \.offset) { _, d in
                    Circle()
                        .fill(splash.color)
                        .overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(width: d.size, height: d.size)
                        // Hidden until the drop lands, then they fly out and shrink away.
                        .scaleEffect(phase == .burst ? 0.05 : 1)
                        .animation(.easeIn(duration: 0.65), value: phase)
                        .opacity(phase == .burst ? 1 : 0)
                        .position(
                            x: center.x + (phase == .burst ? cos(d.angle) * d.distance : 0),
                            y: center.y + (phase == .burst ? sin(d.angle) * d.distance : 0)
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeIn(duration: 0.22)) {
                phase = .landed
            } completion: {
                withAnimation(.easeOut(duration: 0.6)) { phase = .burst }
            }
        }
    }
}

/// A classic drop shape, point up.
struct Teardrop: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        let r = w / 2
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - r),
            control1: CGPoint(x: rect.midX + w * 0.15, y: rect.minY + h * 0.25),
            control2: CGPoint(x: rect.maxX, y: rect.maxY - r * 1.6)
        )
        p.addArc(center: CGPoint(x: rect.midX, y: rect.maxY - r), radius: r,
                 startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
        p.addCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control1: CGPoint(x: rect.minX, y: rect.maxY - r * 1.6),
            control2: CGPoint(x: rect.midX - w * 0.15, y: rect.minY + h * 0.25)
        )
        p.closeSubpath()
        return p
    }
}

/// A slightly wobbly circle, like a dab of paint.
struct PaintBlob: Shape {
    var seed: UInt64 = 1

    func path(in rect: CGRect) -> Path {
        var rng = SplitMix64(seed: seed)
        let phase1 = Double.random(in: 0...(2 * .pi), using: &rng)
        let phase2 = Double.random(in: 0...(2 * .pi), using: &rng)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var p = Path()
        let steps = 72
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let wobble = 1 + 0.05 * sin(5 * t + phase1) + 0.035 * sin(3 * t + phase2)
            let r = radius * 0.94 * CGFloat(wobble)
            let point = CGPoint(x: center.x + r * CGFloat(cos(t)), y: center.y + r * CGFloat(sin(t)))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }
}

extension Paint {
    /// Stable per-paint seed so each paint keeps its own blob shape.
    var blobSeed: UInt64 {
        id.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    let colors: [Color]
    @State private var fallen = false

    private struct Piece {
        let x: CGFloat
        let drift: CGFloat
        let size: CGSize
        let spin: Double
        let delay: Double
        let duration: Double
        let colorIndex: Int
    }

    @State private var pieces: [Piece] = ConfettiView.makePieces()

    private static func makePieces() -> [Piece] {
        var rng = SplitMix64(seed: UInt64.random(in: 1...UInt64.max))
        return (0..<60).map { i in
            Piece(
                x: CGFloat.random(in: 0...1, using: &rng),
                drift: CGFloat.random(in: -60...60, using: &rng),
                size: CGSize(width: CGFloat.random(in: 6...11, using: &rng), height: CGFloat.random(in: 10...18, using: &rng)),
                spin: Double.random(in: 180...720, using: &rng),
                delay: Double.random(in: 0...0.4, using: &rng),
                duration: Double.random(in: 1.4...2.4, using: &rng),
                colorIndex: i
            )
        }
    }

    var body: some View {
        GeometryReader { geo in
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, piece in
                RoundedRectangle(cornerRadius: 2)
                    .fill(colors.isEmpty ? Color.orange : colors[piece.colorIndex % colors.count])
                    .frame(width: piece.size.width, height: piece.size.height)
                    .rotationEffect(.degrees(fallen ? piece.spin : 0))
                    .position(
                        x: piece.x * geo.size.width + (fallen ? piece.drift : 0),
                        y: fallen ? geo.size.height + 40 : -30
                    )
                    .animation(.easeIn(duration: piece.duration).delay(piece.delay), value: fallen)
            }
        }
        .allowsHitTesting(false)
        .onAppear { fallen = true }
    }
}

// MARK: - Buttons

/// Squishes on press and springs back.
struct BouncyButtonStyle: ButtonStyle {
    /// Defaults to the theme's accent.
    var tint: Color?
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        BouncyButtonBody(configuration: configuration, customTint: tint, prominent: prominent)
    }
}

private struct BouncyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let customTint: Color?
    let prominent: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.theme) private var theme

    private var tint: Color { customTint ?? theme.accent }

    var body: some View {
        configuration.label
            .font(.headline)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .frame(minHeight: 50)
            .foregroundStyle(prominent ? (customTint == nil ? theme.onAccent : Color.white) : tint)
            .background(
                Capsule().fill(prominent ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(tint.opacity(0.14)))
            )
            .shadow(color: prominent ? tint.opacity(0.35) : .clear, radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .saturation(isEnabled ? 1 : 0)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(.spring(response: 0.25, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

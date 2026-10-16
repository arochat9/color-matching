import SwiftUI

/// The painter's color wheel with colors pinned to their hues, and the harmony they make joined up.
struct HarmonyWheel: View {
    struct Dot: Identifiable {
        enum Style { case shown, answer, pick }
        let id = UUID()
        let color: WheelColor
        let style: Style
    }

    let dots: [Dot]
    @Environment(\.theme) private var theme

    private let ringWidth: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = size / 2 - ringWidth / 2 - 6
            ZStack {
                Circle()
                    .strokeBorder(HarmonyWheel.gradient, lineWidth: ringWidth)
                    .frame(width: size - 12, height: size - 12)
                    .opacity(0.9)
                harmonyShape(center: center, radius: radius)
                    .stroke(theme.ink.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                ForEach(dots) { dot in
                    dotView(dot)
                        .position(HarmonyWheel.point(hue: dot.color.hue, center: center, radius: radius))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// The polygon through the harmony's members (not your pick), in order around the wheel.
    private func harmonyShape(center: CGPoint, radius: CGFloat) -> Path {
        let hues = dots.filter { $0.style != .pick }.map(\.color.hue).sorted()
        return Path { path in
            guard hues.count > 1 else { return }
            path.addLines(hues.map { HarmonyWheel.point(hue: $0, center: center, radius: radius) })
            if hues.count > 2 { path.closeSubpath() }
        }
    }

    @ViewBuilder
    private func dotView(_ dot: Dot) -> some View {
        switch dot.style {
        case .shown:
            Circle().fill(dot.color.swiftUIColor)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        case .answer:
            Circle().fill(dot.color.swiftUIColor)
                .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                .overlay(Circle().strokeBorder(theme.ink, lineWidth: 1.5).padding(-3))
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
        case .pick:
            Circle().fill(dot.color.swiftUIColor)
                .overlay(Circle().strokeBorder(theme.ink, style: StrokeStyle(lineWidth: 2, dash: [3, 2])))
                .frame(width: 18, height: 18)
        }
    }

    /// 0° at the top, going clockwise.
    static func point(hue: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let angle = hue * .pi / 180
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }

    static let gradient = AngularGradient(
        colors: stride(from: 0.0, through: 360, by: 10).map { WheelColor(hue: $0, saturation: 0.85, brightness: 0.95).swiftUIColor },
        center: .center,
        startAngle: .degrees(-90),
        endAngle: .degrees(270)
    )
}

/// Saturation left to right, brightness bottom to top, for one hue: the square in a color picker.
struct ToneSquare: View {
    let hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [.white, WheelColor(hue: hue, saturation: 1, brightness: 1).swiftUIColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                Circle()
                    .fill(WheelColor(hue: hue, saturation: saturation, brightness: brightness).swiftUIColor)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .frame(width: 30, height: 30)
                    .position(x: saturation * geo.size.width, y: (1 - brightness) * geo.size.height)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    saturation = min(max(value.location.x / geo.size.width, 0), 1)
                    brightness = 1 - min(max(value.location.y / geo.size.height, 0), 1)
                }
            )
        }
        .accessibilityElement()
        .accessibilityLabel("Saturation and brightness")
        .accessibilityValue("\(Int(saturation * 100))% saturation, \(Int(brightness * 100))% brightness")
    }
}

/// A hue slider limited to one slice of the wheel.
struct HueStrip: View {
    let range: ClosedRange<Double>
    @Binding var hue: Double

    /// The hue measured from the start of the range, so a red slice can run from -45° to 45°.
    private var position: Double {
        range.lowerBound + ColorWheel.normalized(hue - range.lowerBound)
    }

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(
                    colors: stride(from: range.lowerBound, through: range.upperBound, by: span / 12)
                        .map { WheelColor(hue: $0, saturation: 1, brightness: 1).swiftUIColor },
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                Circle()
                    .fill(WheelColor(hue: hue, saturation: 1, brightness: 1).swiftUIColor)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
                    .frame(width: 34, height: 34)
                    .position(x: (position - range.lowerBound) / span * geo.size.width, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let t = min(max(value.location.x / geo.size.width, 0), 1)
                    hue = range.lowerBound + t * span
                }
            )
        }
        .frame(height: 34)
        .accessibilityElement()
        .accessibilityLabel("Hue")
        .accessibilityValue(ColorWheel.name(forHue: hue))
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 3.0 : -3.0
            hue = min(max(position + step, range.lowerBound), range.upperBound)
        }
    }
}

/// A row of color chips, with an optional extra slot that shows a "?" until it's filled.
struct ColorSet: View {
    let colors: [WheelColor]
    var slotTitle: String?
    var slot: WheelColor?
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, color in
                chip(color.swiftUIColor)
            }
            if let slotTitle {
                ZStack {
                    if let slot {
                        chip(slot.swiftUIColor)
                            .transition(.scale(scale: 0.6).combined(with: .opacity))
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(theme.info, style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
                        Image(systemName: "questionmark").font(.title.weight(.bold)).foregroundStyle(theme.info)
                    }
                }
                .overlay(alignment: .bottom) {
                    Text(slotTitle)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(6)
                }
            }
        }
        .frame(height: 110)
    }

    private func chip(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(color)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: color.opacity(0.35), radius: 10, y: 6)
    }
}

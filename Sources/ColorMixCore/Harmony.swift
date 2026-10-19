import Foundation

/// The painter's (red-yellow-blue) color wheel. Harmony rules are taught on this wheel, so red sits
/// opposite green and blue opposite orange, the way painters learn them (on a screen's RGB wheel
/// red sits opposite cyan instead).
public enum ColorWheel {
    /// Matching hues on the painter's wheel and the RGB wheel, in degrees.
    private static let rybStops: [Double] = [0, 60, 120, 180, 240, 300, 360]
    private static let rgbStops: [Double] = [0, 30, 60, 120, 230, 280, 360]

    /// The 12 hues of the classic painter's wheel, every 30° starting at red.
    public static let names = [
        "red", "red-orange", "orange", "yellow-orange", "yellow", "yellow-green",
        "green", "blue-green", "blue", "blue-violet", "violet", "red-violet",
    ]

    public static func normalized(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// Shortest way around the wheel from `a` to `b`, in -180...180.
    public static func signedDistance(from a: Double, to b: Double) -> Double {
        let d = normalized(b - a)
        return d > 180 ? d - 360 : d
    }

    public static func distance(_ a: Double, _ b: Double) -> Double {
        abs(signedDistance(from: a, to: b))
    }

    public static func rgbHue(fromRYB hue: Double) -> Double {
        interpolate(normalized(hue), from: rybStops, to: rgbStops)
    }

    public static func rybHue(fromRGB hue: Double) -> Double {
        interpolate(normalized(hue), from: rgbStops, to: rybStops)
    }

    private static func interpolate(_ x: Double, from: [Double], to: [Double]) -> Double {
        for i in 1..<from.count where x <= from[i] {
            let t = (x - from[i - 1]) / (from[i] - from[i - 1])
            return normalized(to[i - 1] + t * (to[i] - to[i - 1]))
        }
        return 0
    }

    /// The nearest of the 12 classic hue names.
    public static func name(forHue hue: Double) -> String {
        names[Int((normalized(hue) / 30).rounded()) % 12]
    }
}

/// A color described the way the theory screens use it: a hue on the painter's wheel plus
/// saturation and brightness (0...1, as in an HSB color picker).
public struct WheelColor: Hashable, Sendable {
    public var hue: Double
    public var saturation: Double
    public var brightness: Double

    public init(hue: Double, saturation: Double, brightness: Double) {
        self.hue = ColorWheel.normalized(hue)
        self.saturation = min(max(saturation, 0), 1)
        self.brightness = min(max(brightness, 0), 1)
    }

    public var srgb: SRGB {
        let h = ColorWheel.rgbHue(fromRYB: hue) / 60
        let c = brightness * saturation
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        let rgb: (Double, Double, Double)
        switch Int(h) % 6 {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        return SRGB(r: rgb.0 + m, g: rgb.1 + m, b: rgb.2 + m)
    }

    public var hueName: String { ColorWheel.name(forHue: hue) }

    /// Tone word plus hue, like "dusty blue-green".
    public var name: String { "\(Tone.nearest(to: self).adjective) \(hueName)" }

    func toneDistance(to other: WheelColor) -> Double {
        let ds = saturation - other.saturation, db = brightness - other.brightness
        return (ds * ds + db * db).squareRoot()
    }
}

/// How saturated and how light a set of colors is. Colors that share a tone read as one family
/// even when their hues are far apart.
public enum Tone: String, CaseIterable, Sendable {
    case pastel, vivid, muted, deep

    public var saturation: Double {
        switch self {
        case .pastel: 0.30
        case .vivid: 0.85
        case .muted: 0.35
        case .deep: 0.80
        }
    }

    public var brightness: Double {
        switch self {
        case .pastel: 0.96
        case .vivid: 0.95
        case .muted: 0.68
        case .deep: 0.52
        }
    }

    public var adjective: String {
        switch self {
        case .pastel: "pale"
        case .vivid: "bright"
        case .muted: "dusty"
        case .deep: "deep"
        }
    }

    /// How the tone reads, for explanations.
    public var description: String {
        switch self {
        case .pastel: "soft and pale"
        case .vivid: "bright and saturated"
        case .muted: "dusty and muted"
        case .deep: "deep and rich"
        }
    }

    public func color(hue: Double) -> WheelColor {
        WheelColor(hue: hue, saturation: saturation, brightness: brightness)
    }

    public static func nearest(to color: WheelColor) -> Tone {
        allCases.min { color.toneDistance(to: $0.color(hue: 0)) < color.toneDistance(to: $1.color(hue: 0)) }!
    }
}

/// The classic color-harmony rules, as positions on the painter's wheel.
public enum HarmonyRule: String, CaseIterable, Sendable {
    case complementary, analogous, splitComplementary, triadic, square

    public var title: String {
        switch self {
        case .complementary: "Complementary"
        case .analogous: "Analogous"
        case .splitComplementary: "Split complementary"
        case .triadic: "Triadic"
        case .square: "Square"
        }
    }

    /// Where each member sits on the wheel, relative to the first.
    public var offsets: [Double] {
        switch self {
        case .complementary: [0, 180]
        case .analogous: [0, 30, 60]
        case .splitComplementary: [0, 150, 210]
        case .triadic: [0, 120, 240]
        case .square: [0, 90, 180, 270]
        }
    }

    /// What the rule is, in a sentence fragment that follows "a <title> set:".
    public var summary: String {
        switch self {
        case .complementary: "two colors straight across the wheel from each other, so each makes the other look stronger"
        case .analogous: "neighbors on the wheel, 30° apart, which always feel calm and related"
        case .splitComplementary: "one color plus the two neighbors of its opposite, punchy like a complement but easier to balance"
        case .triadic: "three colors evenly spaced, 120° apart, for a lively but balanced set"
        case .square: "four colors evenly spaced, 90° apart: two complementary pairs"
        }
    }
}

public enum Harmony {
    /// How far (in degrees) `hues` are from forming `rule`: 0 is a perfect fit. Every hue must land on a
    /// different position of the rule (up to the rule's size), so three near-identical hues aren't "complementary".
    public static func fit(hues: [Double], rule: HarmonyRule) -> Double {
        let offsets = rule.offsets
        var best = Double.infinity
        for anchor in hues {
            for offset in offsets {
                let rotation = anchor - offset
                var slots = Set<Int>()
                var error = 0.0
                for hue in hues {
                    let slot = offsets.indices.min {
                        ColorWheel.distance(hue, rotation + offsets[$0]) < ColorWheel.distance(hue, rotation + offsets[$1])
                    }!
                    slots.insert(slot)
                    error = max(error, ColorWheel.distance(hue, rotation + offsets[slot]))
                }
                if slots.count >= min(hues.count, offsets.count) {
                    best = min(best, error)
                }
            }
        }
        return best
    }

    /// The rule these hues fit best, and how far off they are. Simpler rules win ties.
    public static func bestFit(hues: [Double]) -> (rule: HarmonyRule, error: Double) {
        HarmonyRule.allCases
            .map { (rule: $0, error: fit(hues: hues, rule: $0)) }
            .min { $0.error < $1.error }!
    }
}

/// The six broad hue families the "find the hue" picker is limited to.
public enum HueFamily: String, CaseIterable, Sendable {
    case red, orange, yellow, green, blue, purple

    /// Center on the painter's wheel.
    public var center: Double {
        Double(HueFamily.allCases.firstIndex(of: self)!) * 60
    }

    /// The slice of the wheel the picker offers: 45° either side of the center.
    public var range: ClosedRange<Double> { (center - 45)...(center + 45) }

    public static func nearest(to hue: Double) -> HueFamily {
        allCases.min { ColorWheel.distance(hue, $0.center) < ColorWheel.distance(hue, $1.center) }!
    }
}

private extension RandomNumberGenerator {
    /// A tone's color with a little wobble, so a set doesn't look machine-made.
    mutating func jittered(_ tone: Tone, hue: Double) -> WheelColor {
        WheelColor(
            hue: hue + Double.random(in: -3...3, using: &self),
            saturation: tone.saturation + Double.random(in: -0.04...0.04, using: &self),
            brightness: tone.brightness + Double.random(in: -0.04...0.04, using: &self)
        )
    }
}

/// "Which of these five fits the set?": the set is a harmony with one member missing, and all five
/// options come from the missing color's hue family (five greens, say), so you have to find the right shade.
public struct FitPuzzle: Sendable {
    public enum Kind: Sendable {
        /// Completes the harmony in the set's tone.
        case answer
        /// Right tone, but its hue is off enough to fit no harmony with the set.
        case offHue
        /// Right hue, but a clashing tone.
        case offTone
    }

    public struct Option: Identifiable, Sendable {
        public let id: Int
        public let color: WheelColor
        public let kind: Kind
    }

    public let rule: HarmonyRule
    public let tone: Tone
    public let shown: [WheelColor]
    public let options: [Option]

    public var answer: Option { options.first { $0.kind == .answer }! }
    /// The hue family every option comes from.
    public var family: HueFamily { HueFamily.nearest(to: answer.color.hue) }

    /// Any hue this far from every harmony with the set counts as not fitting.
    static let offHueMinimum: Double = 18
    /// How far an off hue sits from the answer and from each other, so the options look different.
    static let offHueSpacing: Double = 15

    public static func make<R: RandomNumberGenerator>(using rng: inout R) -> FitPuzzle {
        while true {
            if let puzzle = attempt(using: &rng) { return puzzle }
        }
    }

    private static func attempt<R: RandomNumberGenerator>(using rng: inout R) -> FitPuzzle? {
        // Complementary needs only two colors, so with one shown almost any hue fits some rule.
        let rule = [HarmonyRule.analogous, .splitComplementary, .triadic, .square].randomElement(using: &rng)!
        let tone = Tone.allCases.randomElement(using: &rng)!
        let base = Double.random(in: 0..<360, using: &rng)
        var hues = rule.offsets.map { base + $0 }
        let answerHue = hues.remove(at: Int.random(in: hues.indices, using: &rng))
        let shown = hues.shuffled(using: &rng).map { rng.jittered(tone, hue: $0) }

        let answer = tone.color(hue: answerHue)
        let family = HueFamily.nearest(to: answerHue)
        // Two in the right hue but a clashing tone (every tone clashes with at least two others).
        let clashing = Tone.allCases.filter { $0.color(hue: 0).toneDistance(to: tone.color(hue: 0)) >= 0.4 }
        let offTones = clashing.shuffled(using: &rng).prefix(2).map { $0.color(hue: answerHue + Double.random(in: -6...6, using: &rng)) }

        // Two in the right tone, with a hue from the same family that's off enough to fit no harmony.
        var offHues: [Double] = []
        for _ in 0..<300 where offHues.count < 2 {
            let hue = Double.random(in: family.range, using: &rng)
            guard ColorWheel.distance(hue, answerHue) >= offHueMinimum + 4,
                  offHues.allSatisfy({ ColorWheel.distance($0, hue) >= offHueSpacing }) else { continue }
            if Harmony.bestFit(hues: shown.map(\.hue) + [hue]).error >= offHueMinimum { offHues.append(hue) }
        }
        guard offHues.count == 2 else { return nil }

        let colors: [(WheelColor, Kind)] = [(answer, .answer)]
            + offTones.map { ($0, .offTone) }
            + offHues.map { (tone.color(hue: $0), .offHue) }
        let options = colors.shuffled(using: &rng).enumerated().map { Option(id: $0.offset, color: $0.element.0, kind: $0.element.1) }
        return FitPuzzle(rule: rule, tone: tone, shown: shown, options: options)
    }

    /// Why an option does or doesn't fit.
    public func explanation(for option: Option) -> String {
        let name = option.color.name.capitalizingFirst
        switch option.kind {
        case .answer:
            return "\(name) completes a \(rule.title.lowercased()) set: \(rule.summary). It's also \(tone.description), like the others."
        case .offHue:
            return "\(name) has the right tone, but its hue is a little off: it doesn't line up with these on the wheel, so it fits no harmony."
        case .offTone:
            return "\(name) is the right hue, but it's \(Tone.nearest(to: option.color).description) while the set is \(tone.description)."
        }
    }
}

/// "Find the <family> that fits": the set is a harmony with one member missing, and you pick the
/// missing color with a picker limited to its hue family.
public struct HuePuzzle: Sendable {
    public let rule: HarmonyRule
    public let tone: Tone
    public let shown: [WheelColor]
    public let target: WheelColor
    public var family: HueFamily { HueFamily.nearest(to: target.hue) }

    public static func make<R: RandomNumberGenerator>(using rng: inout R) -> HuePuzzle {
        let rule = HarmonyRule.allCases.randomElement(using: &rng)!
        let tone = Tone.allCases.randomElement(using: &rng)!
        let base = Double.random(in: 0..<360, using: &rng)
        var hues = rule.offsets.map { base + $0 }
        let targetHue = hues.remove(at: Int.random(in: hues.indices, using: &rng))
        let shown = hues.shuffled(using: &rng).map { rng.jittered(tone, hue: $0) }
        return HuePuzzle(rule: rule, tone: tone, shown: shown, target: tone.color(hue: targetHue))
    }

    public func grade(_ pick: WheelColor) -> HueGrade {
        let hueError = ColorWheel.distance(pick.hue, target.hue)
        let toneDistance = pick.toneDistance(to: target)
        let hueScore = min(max(1 - max(0, hueError - 4) / 40, 0), 1)
        let toneScore = min(max(1 - max(0, toneDistance - 0.04) / 0.4, 0), 1)

        var tips: [String] = []
        let signed = ColorWheel.signedDistance(from: target.hue, to: pick.hue)
        if abs(signed) <= 6 {
            tips.append("Hue is spot on.")
        } else {
            let toward = ColorWheel.name(forHue: target.hue + (signed > 0 ? 30 : -30))
            tips.append("Your hue is \(Int(abs(signed).rounded()))° too far toward \(toward).")
        }
        var toneNotes: [String] = []
        let db = pick.brightness - target.brightness, ds = pick.saturation - target.saturation
        if abs(db) > 0.08 { toneNotes.append(db > 0 ? "too light" : "too dark") }
        if abs(ds) > 0.08 { toneNotes.append(ds > 0 ? "too vivid" : "too dull") }
        if toneNotes.isEmpty {
            tips.append("The tone matches the set.")
        } else {
            tips.append("A bit \(toneNotes.joined(separator: " and ")): the set is \(tone.description).")
        }

        // Missing the intended rule can still land on another one, which is worth knowing.
        var alsoFits: HarmonyRule?
        if hueError > 8 {
            let other = Harmony.bestFit(hues: shown.map(\.hue) + [pick.hue])
            if other.rule != rule, other.error <= 8 { alsoFits = other.rule }
        }
        return HueGrade(
            percent: 100 * (0.7 * hueScore + 0.3 * toneScore),
            hueError: hueError,
            toneDistance: toneDistance,
            tips: tips,
            alsoFits: alsoFits
        )
    }

    public var explanation: String {
        "\(target.name.capitalizingFirst) completes a \(rule.title.lowercased()) set: \(rule.summary)."
    }
}

public struct HueGrade: Sendable {
    public let percent: Double
    public let hueError: Double
    public let toneDistance: Double
    public let tips: [String]
    /// Another harmony your pick happens to make with the set.
    public let alsoFits: HarmonyRule?

    /// The score that counts toward your streak.
    public static let passing: Double = 90
    public var passes: Bool { percent >= HueGrade.passing }
}

private extension String {
    var capitalizingFirst: String { prefix(1).uppercased() + dropFirst() }
}

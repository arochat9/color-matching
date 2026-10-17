import Foundation

/// A goal color to match. `sourceRecipe` is set when the goal was made by mixing palette paints,
/// `name` when the goal is a named color from the color-name list.
public struct Challenge: Hashable, Sendable {
    public let target: SRGB
    public let sourceRecipe: Recipe?
    public let name: String?

    public init(target: SRGB, sourceRecipe: Recipe? = nil, name: String? = nil) {
        self.target = target
        self.sourceRecipe = sourceRecipe
        self.name = name
    }
}

public enum ChallengeGenerator {
    /// A goal that is guaranteed to be mixable: 2–3 random paints from the palette in random parts.
    public static func reachable<R: RandomNumberGenerator>(palette: [Paint], using rng: inout R) -> Challenge {
        var fallback: Challenge?
        for _ in 0..<30 {
            let maxCount = min(3, palette.count)
            let count = maxCount <= 2 ? maxCount : (Int.random(in: 0..<3, using: &rng) == 0 ? 2 : 3)
            let paints = Array(palette.shuffled(using: &rng).prefix(count))
            let recipe = Recipe(paints.map { Ingredient(paint: $0, parts: Int.random(in: 1...5, using: &rng)) }).simplified.sorted
            guard let color = recipe.color else { continue }
            let challenge = Challenge(target: color, sourceRecipe: recipe)
            fallback = challenge
            // Skip near-black and near-white goals; they make for dull rounds.
            let l = color.lab.l
            if l > 18 && l < 95 { return challenge }
        }
        return fallback ?? Challenge(target: SRGB(r: 0.5, g: 0.5, b: 0.5))
    }
}

public struct MatchResult: Hashable, Sendable {
    public let deltaE: Double
    /// 0...100. ΔE 0 is 100%, ΔE 3 ("very close") is 90%, ΔE 30 or more is 0%.
    public let matchPercent: Double
    public let verdict: String
    public let feedback: [String]

    /// The bar for a round to count toward the lifetime score.
    public static let scoringThreshold = 90.0
    public var counts: Bool { matchPercent >= MatchResult.scoringThreshold }
}

public enum Scoring {
    public static func matchPercent(deltaE: Double) -> Double {
        max(0, min(100, 100 * (1 - deltaE / 30)))
    }

    public static func evaluate(target: SRGB, guess: SRGB) -> MatchResult {
        let t = target.lab, g = guess.lab
        let dE = ColorDifference.deltaE2000(t, g)
        return MatchResult(
            deltaE: dE,
            matchPercent: matchPercent(deltaE: dE),
            verdict: verdict(deltaE: dE),
            feedback: feedback(target: t, guess: g)
        )
    }

    public static func verdict(deltaE: Double) -> String {
        switch deltaE {
        // 90% or better passes; a perfect 100% almost never happens, so it gets no word of its own.
        case ..<3: return "Match"
        case ..<6: return "Close"
        case ..<12: return "Getting there"
        default: return "Way off"
        }
    }

    /// Plain-language hints about value (lightness), saturation and hue.
    public static func feedback(target t: Lab, guess g: Lab) -> [String] {
        var notes: [String] = []
        let dL = g.l - t.l
        if dL > 3 {
            notes.append("Too light: use less white")
        } else if dL < -3 {
            notes.append("Too dark: add white")
        }

        let dC = g.chroma - t.chroma
        if dC > 4 {
            notes.append("Too vivid: add a touch of its complement")
        } else if dC < -4 {
            notes.append("Too dull: less black, more pure color")
        }

        if t.chroma > 8 && g.chroma > 8 {
            var dh = g.hue - t.hue
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
            let goalFamily = hueFamily(t.hue), yourFamily = hueFamily(g.hue)
            if goalFamily != yourFamily {
                notes.append("Wrong hue: goal is \(goalFamily), yours is \(yourFamily)")
            } else if abs(dh) > 6 {
                let toward = hueFamily(t.hue - (dh > 0 ? 25 : -25))
                notes.append("Hue slightly off: nudge toward \(toward)")
            }
        } else if t.chroma <= 8 && g.chroma > 12 {
            notes.append("Too colorful: the goal is nearly gray")
        }

        if notes.isEmpty { notes.append("Lightness, color and hue all line up") }
        return notes
    }

    /// A rough color name for a CIELAB hue angle.
    public static func hueFamily(_ hue: Double) -> String {
        let h = (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        switch h {
        case 20..<40: return "red"
        case 40..<75: return "orange"
        case 75..<105: return "yellow"
        case 105..<165: return "green"
        case 165..<230: return "teal"
        case 230..<290: return "blue"
        case 290..<345: return "purple"
        default: return "magenta"
        }
    }
}

/// Small deterministic RNG so a seed always produces the same rounds (used for screenshots and tests).
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

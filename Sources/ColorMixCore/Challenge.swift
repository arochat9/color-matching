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

/// What kind of goal colors to deal.
public enum GoalMode: String, CaseIterable, Identifiable, Sendable {
    /// A real named color (cerulean, lemon yellow, ...). Some are brighter than any paint mix.
    case named
    /// Any random hex code. Some can't be reached with the palette.
    case anyHex

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .named: return "Named colors"
        case .anyHex: return "Any hex code"
        }
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

    /// Any hex color at all. Some will be impossible to hit with the palette, which is a lesson in itself.
    public static func anyHex<R: RandomNumberGenerator>(using rng: inout R) -> Challenge {
        Challenge(target: SRGB(
            r: Double(Int.random(in: 0...255, using: &rng)) / 255,
            g: Double(Int.random(in: 0...255, using: &rng)) / 255,
            b: Double(Int.random(in: 0...255, using: &rng)) / 255
        ))
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
        case ..<1: return "Perfect. The difference is invisible."
        case ..<3: return "Very close. Only a trained eye would notice."
        case ..<6: return "Close, but you can see the difference side by side."
        case ..<12: return "In the neighborhood."
        default: return "Clearly a different color."
        }
    }

    /// Plain-language hints about value (lightness), saturation and hue.
    public static func feedback(target t: Lab, guess g: Lab) -> [String] {
        var notes: [String] = []
        let dL = g.l - t.l
        if dL > 3 {
            notes.append("Too light. Use less white, or add a touch of a darker paint.")
        } else if dL < -3 {
            notes.append("Too dark. Add white, or use less black and umber.")
        }

        let dC = g.chroma - t.chroma
        if dC > 4 {
            notes.append("Too vivid. Dull it with its complement, black, or an earth color.")
        } else if dC < -4 {
            notes.append("Too dull. Use more of the pure colors and less black or umber.")
        }

        if t.chroma > 8 && g.chroma > 8 {
            var dh = g.hue - t.hue
            if dh > 180 { dh -= 360 } else if dh < -180 { dh += 360 }
            let goalFamily = hueFamily(t.hue), yourFamily = hueFamily(g.hue)
            if goalFamily != yourFamily {
                notes.append("Hue: the goal is \(goalFamily), yours is \(yourFamily).")
            } else if abs(dh) > 6 {
                let toward = hueFamily(t.hue - (dh > 0 ? 25 : -25))
                notes.append("Hue is a little off. Nudge it toward \(toward).")
            }
        } else if t.chroma <= 8 && g.chroma > 12 {
            notes.append("The goal is nearly a neutral gray; yours has too much color in it.")
        }

        if notes.isEmpty { notes.append("Value, saturation and hue all line up.") }
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

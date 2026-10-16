import SwiftUI

/// What the player sees after pressing Submit.
struct RoundResult: Identifiable {
    let id = UUID()
    let target: SRGB
    let targetName: String?
    let guess: SRGB
    let guessRecipe: Recipe
    let match: MatchResult
    let simplest: Solution
    let closest: Solution
    /// True when this submission added a point to the lifetime score.
    let scoredPoint: Bool
    /// A color picked from the library: practice only, never scores.
    let isPractice: Bool

    /// The best match the palette can reach at all; below 100% when the goal is outside the palette.
    var bestPossiblePercent: Double { Scoring.matchPercent(deltaE: closest.deltaE) }
}

final class GameModel: ObservableObject {
    static let lifetimeScoreKey = "lifetimeMatches"

    @Published var paletteID: String {
        didSet {
            guard paletteID != oldValue else { return }
            UserDefaults.standard.set(paletteID, forKey: "paletteID")
            nextRound()
        }
    }
    @Published var goalMode: GoalMode {
        didSet {
            guard goalMode != oldValue else { return }
            UserDefaults.standard.set(goalMode.rawValue, forKey: "goalMode")
            nextRound()
        }
    }
    @Published private(set) var challenge: Challenge {
        didSet { updateGoalName() }
    }
    @Published private(set) var goalName: GoalName?
    @Published private(set) var parts: [String: Int] = [:]
    @Published var result: RoundResult?
    @Published private(set) var lifetimeScore: Int
    @Published private(set) var roundScored = false
    /// True while mixing a color picked from the library. Practice rounds never earn a star.
    @Published private(set) var isPractice = false
    /// How far (ΔE) the goal is from anything the palette can mix; large means it can't be matched.
    @Published private(set) var goalReach: Double = 0

    private var rng: SplitMix64
    private let solver = RecipeSolver()
    private let persistScore: Bool

    var palette: Palette { Palette.all.first { $0.id == paletteID } ?? .limited }

    var currentRecipe: Recipe {
        Recipe(palette.paints.map { Ingredient(paint: $0, parts: parts[$0.id] ?? 0) })
    }

    var mixColor: SRGB? { currentRecipe.color }

    init(seed: UInt64? = nil, persistScore: Bool = true) {
        let defaults = UserDefaults.standard
        let paletteID = defaults.string(forKey: "paletteID") ?? Palette.limited.id
        let mode = defaults.string(forKey: "goalMode").flatMap(GoalMode.init(rawValue:)) ?? .mixable
        var rng = SplitMix64(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        let palette = Palette.all.first { $0.id == paletteID } ?? .limited
        self.paletteID = palette.id
        self.goalMode = mode
        self.challenge = GameModel.makeChallenge(palette: palette, mode: mode, rng: &rng)
        self.rng = rng
        self.persistScore = persistScore
        self.lifetimeScore = persistScore ? defaults.integer(forKey: GameModel.lifetimeScoreKey) : 0
        updateGoalName()
    }

    /// ~1,000 names: ~210 pigment and classic paint names (Cerulean, Burnt Sienna, ...) plus the
    /// ~800 other names from the XKCD color survey, the names most people actually use.
    static let colorNames = ColorNameIndex(colors: loadNames("pigmentnames") + loadNames("xkcdnames"))

    private static func loadNames(_ resource: String) -> [NamedColor] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "csv"),
              let csv = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return ColorNameIndex(csv: csv).colors
    }

    /// Every named color grouped by hue, for the color library.
    static let librarySections: [(family: String, colors: [NamedColor])] = {
        let order = ["red", "orange", "yellow", "green", "teal", "blue", "purple", "magenta", "neutral"]
        let groups = Dictionary(grouping: colorNames.colors) { color in
            color.lab.chroma < 10 ? "neutral" : Scoring.hueFamily(color.lab.hue)
        }
        return order.compactMap { family in
            guard let colors = groups[family] else { return nil }
            return (family, colors.sorted { $0.lab.l > $1.lab.l })
        }
    }()

    private static var gamuts: [String: PaletteGamut] = [:]

    private static func gamut(for palette: Palette) -> PaletteGamut {
        if let cached = gamuts[palette.id] { return cached }
        let gamut = PaletteGamut(palette: palette.paints)
        gamuts[palette.id] = gamut
        return gamut
    }

    private static func makeChallenge(palette: Palette, mode: GoalMode, rng: inout SplitMix64) -> Challenge {
        switch mode {
        case .anyHex:
            return ChallengeGenerator.anyHex(using: &rng)
        case .named:
            // Any name from the full list, including ones the palette can't quite reach.
            if let named = colorNames.randomElement(using: &rng) {
                return Challenge(target: named.color, name: named.name)
            }
            return ChallengeGenerator.reachable(palette: palette.paints, using: &rng)
        case .mixable:
            return ChallengeGenerator.reachable(palette: palette.paints, using: &rng)
        }
    }

    private func updateGoalName() {
        goalName = GoalName(challenge: challenge)
        goalReach = challenge.sourceRecipe == nil
            ? GameModel.gamut(for: palette).distance(to: challenge.target)
            : 0
    }

    /// True when no mix of this palette gets within "close" range of the goal.
    var goalIsOutOfReach: Bool { goalReach > 6 }

    func parts(of paint: Paint) -> Int { parts[paint.id] ?? 0 }

    func add(_ paint: Paint) {
        parts[paint.id, default: 0] += 1
    }

    func remove(_ paint: Paint) {
        guard let n = parts[paint.id], n > 0 else { return }
        parts[paint.id] = n - 1
    }

    func clearMix() {
        parts = [:]
    }

    func setParts(_ recipe: Recipe) {
        parts = Dictionary(uniqueKeysWithValues: recipe.ingredients.map { ($0.paint.id, $0.parts) })
    }

    func submit() {
        guard let guess = mixColor,
              let solved = solver.solve(for: challenge.target, palette: palette.paints) else { return }
        let match = Scoring.evaluate(target: challenge.target, guess: guess)
        // A round can earn at most one point, however many times you resubmit.
        let earned = match.counts && !roundScored && !isPractice
        if earned {
            roundScored = true
            lifetimeScore += 1
            if persistScore {
                UserDefaults.standard.set(lifetimeScore, forKey: GameModel.lifetimeScoreKey)
            }
        }
        result = RoundResult(
            target: challenge.target,
            targetName: goalName?.headline,
            guess: guess,
            guessRecipe: currentRecipe.sorted,
            match: match,
            simplest: solved.simplest,
            closest: solved.closest,
            scoredPoint: earned,
            isPractice: isPractice
        )
    }

    func nextRound() {
        result = nil
        parts = [:]
        roundScored = false
        isPractice = false
        challenge = GameModel.makeChallenge(palette: palette, mode: goalMode, rng: &rng)
    }

    /// Mix a specific color from the library. It's practice, so it doesn't count toward the score.
    func practice(_ color: NamedColor) {
        result = nil
        parts = [:]
        roundScored = false
        isPractice = true
        challenge = Challenge(target: color.color, name: color.name)
    }
}

/// How a goal is labelled: its nearest name, and how it differs from that name's color.
struct GoalName {
    let name: String
    /// e.g. "lighter, duller"; nil when the goal is essentially that named color.
    let qualifier: String?
    let isExact: Bool

    init?(challenge: Challenge) {
        if let name = challenge.name {
            self.name = name
            qualifier = nil
            isExact = true
        } else if let nearest = GameModel.colorNames.nearest(to: challenge.target) {
            name = nearest.named.name
            isExact = nearest.deltaE < 1.5
            qualifier = isExact ? nil : ColorNameIndex.qualifier(of: challenge.target.lab, relativeTo: nearest.named.lab)
        } else {
            return nil
        }
    }

    /// "Cerulean", or "Close to Cerulean (lighter, duller)".
    var headline: String {
        if isExact { return name }
        if let qualifier { return "Close to \(name) (\(qualifier))" }
        return "Close to \(name)"
    }
}

extension SRGB {
    var swiftUIColor: Color { Color(red: r, green: g, blue: b) }
}

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

    /// ~32k names from github.com/meodai/color-names: nearly every color has an exact match, but most are whimsical.
    static let allNames = loadNames("colornames")
    /// ~200 pigment and everyday names a painter would know (Cerulean, Burnt Sienna, ...).
    static let commonNames = loadNames("commonnames")

    private static func loadNames(_ resource: String) -> ColorNameIndex {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "csv"),
              let csv = try? String(contentsOf: url, encoding: .utf8) else { return ColorNameIndex(colors: []) }
        return ColorNameIndex(csv: csv)
    }

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
            if let named = ChallengeGenerator.named(names: commonNames, gamut: gamut(for: palette), using: &rng) {
                return named
            }
            return ChallengeGenerator.reachable(palette: palette.paints, using: &rng)
        case .mixable:
            return ChallengeGenerator.reachable(palette: palette.paints, using: &rng)
        }
    }

    private func updateGoalName() {
        goalName = GoalName(challenge: challenge)
    }

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
        let earned = match.counts && !roundScored
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
            scoredPoint: earned
        )
    }

    func nextRound() {
        result = nil
        parts = [:]
        roundScored = false
        challenge = GameModel.makeChallenge(palette: palette, mode: goalMode, rng: &rng)
    }
}

/// How a goal is labelled: the nearest common (painter) name, plus the exact name from the big list.
struct GoalName {
    let common: String
    /// e.g. "lighter, duller"; nil when the goal is essentially the common color itself.
    let qualifier: String?
    let isExactCommon: Bool
    /// The closest name in the 32k list, shown in small type. Nil when it would repeat the common name.
    let exact: String?

    init?(challenge: Challenge) {
        let lab = challenge.target.lab
        if let name = challenge.name {
            common = name
            qualifier = nil
            isExactCommon = true
        } else if let nearest = GameModel.commonNames.nearest(to: challenge.target) {
            common = nearest.named.name
            isExactCommon = nearest.deltaE < 1.5
            qualifier = isExactCommon ? nil : ColorNameIndex.qualifier(of: lab, relativeTo: nearest.named.lab)
        } else {
            return nil
        }
        let fine = GameModel.allNames.nearest(to: challenge.target)?.named.name
        exact = fine == common ? nil : fine
    }

    /// "Cerulean", or "Close to Cerulean (lighter, duller)".
    var headline: String {
        if isExactCommon { return common }
        if let qualifier { return "Close to \(common) (\(qualifier))" }
        return "Close to \(common)"
    }
}

extension SRGB {
    var swiftUIColor: Color { Color(red: r, green: g, blue: b) }
}

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

    static let tubesKey = "paletteTubes"
    static let autoExtraKey = "autoExtraTube"
    static let starterMigratedKey = "paletteHasUltramarine"

    /// The tubes you've put on your palette (ids from `DynamicPalette.allPaints`).
    @Published var tubeIDs: Set<String> {
        didSet {
            guard tubeIDs != oldValue else { return }
            UserDefaults.standard.set(Array(tubeIDs), forKey: GameModel.tubesKey)
            paletteChanged()
        }
    }
    /// Whether to add one more tube per goal: the one that gets closest to it.
    @Published var autoExtra: Bool {
        didSet {
            guard autoExtra != oldValue else { return }
            UserDefaults.standard.set(autoExtra, forKey: GameModel.autoExtraKey)
            paletteChanged()
        }
    }
    /// The extra tube picked for this goal, if any.
    @Published private(set) var extraPaint: Paint?
    @Published private(set) var palette: Palette
    @Published private(set) var challenge: Challenge {
        didSet { updateGoalName() }
    }
    @Published private(set) var goalName: GoalName?
    @Published private(set) var parts: [String: Int] = [:] {
        didSet {
            currentRecipe = Recipe(palette.paints.map { Ingredient(paint: $0, parts: parts[$0.id] ?? 0) })
            scheduleRecoveryCheck()
        }
    }
    /// The mix so far, and its color. Stored so redraws during animations don't redo the spectral mixing.
    @Published private(set) var currentRecipe = Recipe([])
    @Published private(set) var mixColor: SRGB?
    /// Best ΔE still reachable by only adding paint to the current mix. Large means you've gone past
    /// the point of no return (usually too light or too dull) and should start a fresh pile.
    @Published private(set) var recoveryDeltaE: Double?
    @Published private(set) var isSolving = false
    @Published var result: RoundResult?
    @Published private(set) var lifetimeScore: Int
    @Published private(set) var roundScored = false
    /// True while mixing a color picked from the library. Practice rounds never earn a star.
    @Published private(set) var isPractice = false
    /// How far (ΔE) the goal is from anything the palette can mix; large means it can't be matched.
    @Published private(set) var goalReach: Double = 0

    private var rng: SplitMix64
    /// Four-paint recipes get slow on big palettes, so those stop at three.
    private var solver: RecipeSolver { RecipeSolver(maxPaints: palette.paints.count > 8 ? 3 : 4) }
    private var recoveryTask: Task<Void, Never>?
    private var reachTask: Task<Void, Never>?
    /// The named colors your paints can mix to 90%, which goals are dealt from. Nil until worked out.
    private var goalPool: [NamedColor]?
    private var poolTask: Task<Void, Never>?
    /// A goal set by a screenshot demo, which the pool shouldn't swap out.
    private var goalIsPinned = false
    private let persistScore: Bool

    /// Your tubes, in the usual palette order.
    var basePaints: [Paint] {
        DynamicPalette.allPaints.filter { tubeIDs.contains($0.id) }
    }

    static func makePalette(base: [Paint], extra: Paint?) -> Palette {
        let paints = base + [extra].compactMap { $0 }
        return Palette(id: paints.map(\.id).joined(separator: "+"), name: "Your palette", summary: "", paints: paints)
    }

    init(seed: UInt64? = nil, persistScore: Bool = true) {
        let defaults = UserDefaults.standard
        var rng = SplitMix64(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        let all = Set(DynamicPalette.allPaints.map(\.id))
        var saved = (defaults.stringArray(forKey: GameModel.tubesKey) ?? []).filter(all.contains)
        // Palettes saved as the old six-tube default get ultramarine, now part of the default.
        if !defaults.bool(forKey: GameModel.starterMigratedKey) {
            if Set(saved) == Set(DynamicPalette.core.map(\.id)) {
                saved.append(Paint.ultramarineBlue.id)
                defaults.set(saved, forKey: GameModel.tubesKey)
            }
            defaults.set(true, forKey: GameModel.starterMigratedKey)
        }
        let tubes = saved.count >= 2 ? Set(saved) : Set(DynamicPalette.starter.map(\.id))
        let autoExtra = defaults.object(forKey: GameModel.autoExtraKey) as? Bool ?? true
        let base = DynamicPalette.allPaints.filter { tubes.contains($0.id) }
        let palette = GameModel.makePalette(base: base, extra: nil)
        self.tubeIDs = tubes
        self.autoExtra = autoExtra
        self.palette = palette
        self.challenge = GameModel.makeChallenge(palette: palette, pool: nil, rng: &rng)
        self.rng = rng
        self.persistScore = persistScore
        self.lifetimeScore = persistScore ? defaults.integer(forKey: GameModel.lifetimeScoreKey) : 0
        updateGoalName()
        updatePool()
    }

    /// Painters' colors: every common artist pigment (by Colour Index code) under its usual tube name,
    /// plus the classic premixed colors such as Payne's Grey and Sap Green.
    static let colorNames = ColorNameIndex(colors: loadNames("paintcolors"))

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

    private static let gamutLock = NSLock()
    private static var gamuts: [String: PaletteGamut] = [:]

    private static func gamut(for palette: Palette) -> PaletteGamut {
        gamutLock.lock()
        defer { gamutLock.unlock() }
        if let cached = gamuts[palette.id] { return cached }
        let gamut = PaletteGamut(palette: palette.paints)
        gamuts[palette.id] = gamut
        return gamut
    }

    private static func makeChallenge(palette: Palette, pool: [NamedColor]?, rng: inout SplitMix64) -> Challenge {
        // Only colors your paints can reach, once that's worked out; any name until then.
        let names = pool.flatMap { $0.isEmpty ? nil : $0 } ?? colorNames.colors
        if let named = names.randomElement(using: &rng) {
            return Challenge(target: named.color, name: named.name)
        }
        return ChallengeGenerator.reachable(palette: palette.paints, using: &rng)
    }

    private func updateGoalName() {
        goalName = GoalName(challenge: challenge)
        updateReach()
    }

    private func paletteChanged() {
        // Keep paint that's still on the palette; tubes you took away leave the mix.
        let ids = Set(basePaints.map(\.id))
        if extraPaint.map({ ids.contains($0.id) }) == true || !autoExtra { extraPaint = nil }
        setPalette()
        parts = parts.filter { id, _ in palette.paints.contains { $0.id == id } }
        updateReach()
        updatePool()
    }

    /// Works out which named colors these paints can reach, off the main thread. On a fresh
    /// palette that means sampling mixes with every possible extra tube.
    private func updatePool() {
        poolTask?.cancel()
        goalPool = nil
        let base = basePaints, autoExtra = autoExtra
        poolTask = Task.detached(priority: .userInitiated) { [weak self] in
            let pool = GameModel.reachableColors(base: base, autoExtra: autoExtra)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.applyPool(pool) }
        }
    }

    static func reachableColors(base: [Paint], autoExtra: Bool) -> [NamedColor] {
        let baseIDs = Set(base.map(\.id))
        let extras = autoExtra ? DynamicPalette.allPaints.filter { !baseIDs.contains($0.id) } : []
        let palettes = extras.isEmpty
            ? [makePalette(base: base, extra: nil)]
            : extras.map { makePalette(base: base, extra: $0) }
        return colorNames.reachable(by: palettes.map(gamut(for:)))
    }

    private func applyPool(_ pool: [NamedColor]) {
        goalPool = pool
        // The first goal is dealt before the pool is ready. Swap it if it's out of reach and untouched.
        let untouched = result == nil && !isPractice && !goalIsPinned && !parts.values.contains { $0 > 0 }
        if untouched, let name = challenge.name, !pool.isEmpty, !pool.contains(where: { $0.name == name }) {
            nextRound()
        }
    }

    private func setPalette() {
        palette = GameModel.makePalette(base: basePaints, extra: extraPaint)
    }

    /// Picks the extra tube and works out how close the palette can get, off the main thread:
    /// the first look at a new palette samples thousands of mixes.
    private func updateReach() {
        reachTask?.cancel()
        let challenge = challenge, base = basePaints, autoExtra = autoExtra
        // A goal mixed from paints is reachable by construction with the tubes it used.
        if let source = challenge.sourceRecipe {
            let baseIDs = Set(base.map(\.id))
            let missing = source.ingredients.map(\.paint).filter { !baseIDs.contains($0.id) }
            if (missing.isEmpty && !autoExtra) || (autoExtra && missing.count == 1 && DynamicPalette.extras.contains(missing[0])) {
                applyReach(extra: missing.first, reach: 0)
                return
            }
        }
        reachTask = Task.detached(priority: .userInitiated) { [weak self] in
            let (extra, reach) = GameModel.bestExtra(for: challenge.target, base: base, autoExtra: autoExtra)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.applyReach(extra: extra, reach: reach) }
        }
    }

    private func applyReach(extra: Paint?, reach: Double) {
        if extra?.id != extraPaint?.id {
            extraPaint = extra
            setPalette()
            parts = parts.filter { id, _ in palette.paints.contains { $0.id == id } }
        }
        goalReach = reach
    }

    /// The extra tube (if turned on) that gets closest to the goal, and how close (ΔE) the palette can then get.
    static func bestExtra(for target: SRGB, base: [Paint], autoExtra: Bool) -> (Paint?, Double) {
        let baseReach = gamut(for: makePalette(base: base, extra: nil)).distance(to: target)
        // Your own paints first: only bring out an extra tube when they can't comfortably get there.
        guard autoExtra, baseReach > comfortableReach else { return (nil, baseReach) }
        var best: (Paint?, Double) = (nil, baseReach)
        let baseIDs = Set(base.map(\.id))
        for extra in DynamicPalette.allPaints where !baseIDs.contains(extra.id) {
            let d = gamut(for: makePalette(base: base, extra: extra)).distance(to: target)
            if d < best.1 { best = (extra, d) }
        }
        return best
    }

    /// ΔE your own paints need to get within before no extra tube is added. Under the 90% bar (ΔE 3),
    /// so a goal they can only just reach still gets a helper tube.
    static let comfortableReach = 2.5

    /// True when no mix of this palette gets within "close" range of the goal.
    var goalIsOutOfReach: Bool { goalReach > 3 }

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
        guard let guess = mixColor, !isSolving else { return }
        isSolving = true
        let solver = self.solver, target = challenge.target, paints = palette.paints
        Task.detached(priority: .userInitiated) {
            let solved = solver.solve(for: target, palette: paints)
            await MainActor.run {
                self.isSolving = false
                if let solved { self.finishSubmit(guess: guess, solved: solved) }
            }
        }
    }

    private func finishSubmit(guess: SRGB, solved: (simplest: Solution, closest: Solution)) {
        let match = Scoring.evaluate(target: challenge.target, guess: guess)
        // Your own mix proves the palette can get at least this close, even when the search missed it.
        let mine = Solution(recipe: currentRecipe.sorted, color: guess, deltaE: match.deltaE)
        let closest = mine.deltaE < solved.closest.deltaE ? mine : solved.closest
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
            closest: closest,
            scoredPoint: earned,
            isPractice: isPractice
        )
    }

    func nextRound() {
        result = nil
        parts = [:]
        goalReach = 0
        roundScored = false
        isPractice = false
        goalIsPinned = false
        challenge = GameModel.makeChallenge(palette: palette, pool: goalPool, rng: &rng)
    }

    /// Swaps in a specific goal without touching the score state (used by the screenshot demos).
    func setDemoChallenge(_ demo: Challenge) {
        goalIsPinned = true
        challenge = demo
    }

    /// Whether this palette could reach the goal at all, ignoring the current mix.
    var paletteCanReachGoal: Bool { !goalIsOutOfReach }

    /// Piles smaller than this are cheap to start over, so they never get the warning.
    static let noReturnMinParts = 10

    /// The current mix can no longer get to 90% within 100 drops (or tripling a bigger pile), though a fresh pile could.
    var isPastPointOfNoReturn: Bool {
        // 90% is ΔE 3. Only when a fresh pile could get there, but adding to this one can't.
        guard currentRecipe.totalParts >= GameModel.noReturnMinParts,
              let recovery = recoveryDeltaE, goalReach <= 3 else { return false }
        return recovery > 3
    }

    private func scheduleRecoveryCheck() {
        recoveryTask?.cancel()
        mixColor = currentRecipe.color
        let recipe = currentRecipe, target = challenge.target, paints = palette.paints
        guard !recipe.isEmpty else {
            recoveryDeltaE = nil
            return
        }
        recoveryTask = Task.detached(priority: .utility) { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let best = RecipeSolver.bestDeltaEByAdding(to: recipe, target: target, palette: paints)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.recoveryDeltaE = best }
        }
    }

    /// Mix a specific color from the library. It's practice, so it doesn't count toward the score.
    func practice(_ color: NamedColor) {
        result = nil
        parts = [:]
        goalReach = 0
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

import Foundation

public struct Solution: Hashable, Sendable {
    public let recipe: Recipe
    public let color: SRGB
    public let deltaE: Double

    public init(recipe: Recipe, color: SRGB, deltaE: Double) {
        self.recipe = recipe
        self.color = color
        self.deltaE = deltaE
    }
}

/// Finds the fewest paints, and the ratio between them, that reproduce a target color.
///
/// It tries every combination of 1 to `maxPaints` paints from the palette at a coarse ratio, then refines each
/// one drop by drop in a pile of up to 100 parts, so the answers are recipes you could
/// actually measure out, including a drop of black in a big pile.
public struct RecipeSolver: Sendable {
    public var maxPaints: Int
    /// A recipe counts as "as good as the best" when it is within this many ΔE of it.
    public var tolerance: Double

    public init(maxPaints: Int = 4, tolerance: Double = 1.0) {
        self.maxPaints = maxPaints
        self.tolerance = tolerance
    }

    /// Ratio resolution per recipe size: two-paint mixes can go up to 1:23, four-paint ones stay coarse.
    func maxTotalParts(paintCount: Int) -> Int {
        switch paintCount {
        case ...1: return 1
        case 2: return 24
        case 3: return 16
        default: return 12
        }
    }

    /// The biggest pile a recipe may call for. Real paint has no cap, and a drop of black in a big pile of
    /// yellow is a real recipe, so after the coarse search every combination is refined up to this.
    public static let maxPileParts = 100

    /// The best recipe for each number of paints, keyed by paint count.
    public func bestByPaintCount(for target: SRGB, palette: [Paint]) -> [Int: Solution] {
        let targetLab = target.lab
        let ks = palette.map { $0.reflectance.map(Mixer.kOverS) }
        let bands = Spectral.bandCount
        var mixed = [Double](repeating: 0, count: bands)

        func deltaE(_ indices: [Int], _ parts: [Double]) -> Double {
            var total = 0.0
            for j in indices.indices { total += parts[j] * palette[indices[j]].strength }
            for i in 0..<bands { mixed[i] = 0 }
            for j in indices.indices {
                let share = parts[j] * palette[indices[j]].strength / total
                let paintKS = ks[indices[j]]
                for i in 0..<bands { mixed[i] += share * paintKS[i] }
            }
            var x = 0.0, y = 0.0, z = 0.0
            for i in 0..<bands {
                let r = Mixer.reflectance(fromKOverS: mixed[i])
                let w = Spectral.weights[i]
                x += w.x * r
                y += w.y * r
                z += w.z * r
            }
            return ColorDifference.deltaE2000(targetLab, SRGB(xyz: XYZ(x: x, y: y, z: z)).lab)
        }

        // Coarse pass: every combination at a modest ratio resolution, keeping the best ratio per combination.
        typealias Candidate = (deltaE: Double, indices: [Int], parts: [Int])
        var best: [Int: Candidate] = [:]
        var shortlist: [Int: [Candidate]] = [:]
        for k in 1...min(maxPaints, palette.count) {
            let limit = maxTotalParts(paintCount: k)
            for indices in combinations(of: palette.count, choose: k) {
                var bestHere: Candidate?
                forEachComposition(count: k, maxTotal: limit) { parts in
                    let dE = deltaE(indices, parts.map(Double.init))
                    if dE < (bestHere?.deltaE ?? .infinity) { bestHere = (dE, indices, parts) }
                }
                guard let bestHere else { continue }
                shortlist[k, default: []].append(bestHere)
            }
            // Fine pass: nudge every combination drop by drop, in a pile of up to `maxPileParts`. The coarse
            // ranking can't be trusted here: 23 yellow to 1 black looks hopeless, while 60 to 1 is spot on.
            for candidate in shortlist[k] ?? [] {
                let refined = k == 1 ? candidate : refine(candidate, deltaE: deltaE)
                if refined.deltaE < (best[k]?.deltaE ?? .infinity) { best[k] = refined }
            }
        }

        var result: [Int: Solution] = [:]
        for (k, entry) in best {
            let recipe = Recipe(zip(entry.indices, entry.parts).map { Ingredient(paint: palette[$0], parts: $1) }).simplified.sorted
            result[k] = Solution(recipe: recipe, color: recipe.color ?? target, deltaE: entry.deltaE)
        }
        return result
    }

    /// Fine-tunes one combination's ratio: first freely, by growing or shrinking one paint at a time (so it can
    /// walk from 23:1 to 60:1), then rounds that ratio to whole drops in every pile size up to `maxPileParts`.
    /// Every paint keeps at least one drop.
    private func refine(
        _ start: (deltaE: Double, indices: [Int], parts: [Int]),
        deltaE: ([Int], [Double]) -> Double
    ) -> (deltaE: Double, indices: [Int], parts: [Int]) {
        let cap = RecipeSolver.maxPileParts
        let indices = start.indices
        let factors: [Double] = [4, 2, 1.4, 1.15, 1.05, 1.015]
        var amounts = start.parts.map(Double.init)
        var current = start.deltaE
        for _ in 0..<80 {
            var improved = false
            for j in amounts.indices {
                for f in factors {
                    for factor in [f, 1 / f] {
                        var trial = amounts
                        trial[j] *= factor
                        // No paint can be under one drop of the biggest pile.
                        let total = trial.reduce(0, +)
                        guard trial.allSatisfy({ $0 / total >= 1 / Double(cap) }) else { continue }
                        let dE = deltaE(indices, trial)
                        if dE < current - 1e-6 {
                            current = dE
                            amounts = trial
                            improved = true
                        }
                    }
                }
            }
            if !improved { break }
        }

        var best = start
        let total = amounts.reduce(0, +)
        for pile in indices.count...cap {
            let parts = amounts.map { max(1, Int(($0 / total * Double(pile)).rounded())) }
            guard parts.reduce(0, +) <= cap else { continue }
            let dE = deltaE(indices, parts.map(Double.init))
            // Strictly better only, so the smallest pile wins a tie.
            if dE < best.deltaE - 1e-6 { best = (dE, indices, parts) }
        }
        return best
    }

    /// The closest recipe overall, and the simplest one that is within `tolerance` of it.
    public func solve(for target: SRGB, palette: [Paint]) -> (simplest: Solution, closest: Solution)? {
        let byCount = bestByPaintCount(for: target, palette: palette)
        guard let closest = byCount.values.min(by: { $0.deltaE < $1.deltaE }) else { return nil }
        let simplest = byCount.keys.sorted()
            .compactMap { byCount[$0] }
            .first { $0.deltaE <= closest.deltaE + tolerance } ?? closest
        return (simplest, closest)
    }
}

public extension RecipeSolver {
    /// The closest you can get to `target` by only *adding* paint to `current`, the way real paint works:
    /// once it's on the palette you can't take it back out. Tries adding up to three paints, from a dab up to
    /// a pile of `maxPile` parts, or `maxGrowth` times its size once it's bigger than that. Returns the best ΔE2000.
    static func bestDeltaEByAdding(
        to current: Recipe, target: SRGB, palette: [Paint], maxGrowth: Double = 3, maxPile: Int = RecipeSolver.maxPileParts
    ) -> Double {
        let targetLab = target.lab
        let bands = Spectral.bandCount
        let ks = palette.map { $0.reflectance.map(Mixer.kOverS) }
        var baseSum = [Double](repeating: 0, count: bands)
        var baseWeight = 0.0
        for ingredient in current.ingredients {
            let w = Double(ingredient.parts) * ingredient.paint.strength
            let paintKS = ingredient.paint.reflectance.map(Mixer.kOverS)
            for i in 0..<bands { baseSum[i] += w * paintKS[i] }
            baseWeight += w
        }
        guard baseWeight > 0 else { return .infinity }
        let pile = Double(current.totalParts)
        let budget = max(pile * (maxGrowth - 1), Double(maxPile) - pile)
        let amounts = [0.005, 0.01, 0.02, 0.05, 0.1, 0.2, 0.35, 0.5, 0.75, 1].map { $0 * budget }

        var best = Double.infinity
        var sum = baseSum
        func evaluate(weight: Double) {
            var x = 0.0, y = 0.0, z = 0.0
            for i in 0..<bands {
                let r = Mixer.reflectance(fromKOverS: sum[i] / weight)
                let w = Spectral.weights[i]
                x += w.x * r
                y += w.y * r
                z += w.z * r
            }
            best = min(best, ColorDifference.deltaE2000(targetLab, SRGB(xyz: XYZ(x: x, y: y, z: z)).lab))
        }
        // Depth-first over sets of up to three added paints, each in one of the amounts.
        func addPaints(from start: Int, depth: Int, weight: Double, added: Double) {
            evaluate(weight: weight)
            guard depth < 3 else { return }
            for p in start..<palette.count {
                for amount in amounts where added + amount <= budget + 1e-9 {
                    let w = amount * palette[p].strength
                    for i in 0..<bands { sum[i] += w * ks[p][i] }
                    addPaints(from: p + 1, depth: depth + 1, weight: weight + w, added: added + amount)
                    for i in 0..<bands { sum[i] -= w * ks[p][i] }
                }
            }
        }
        addPaints(from: 0, depth: 0, weight: baseWeight, added: 0)
        return best
    }
}

/// All k-element index subsets of 0..<n, in lexicographic order.
func combinations(of n: Int, choose k: Int) -> [[Int]] {
    guard k > 0, k <= n else { return [] }
    var result: [[Int]] = []
    var current: [Int] = []
    func build(from start: Int) {
        if current.count == k {
            result.append(current)
            return
        }
        guard start < n else { return }
        for i in start..<n {
            current.append(i)
            build(from: i + 1)
            current.removeLast()
        }
    }
    build(from: 0)
    return result
}

/// Calls `body` with every vector of `count` positive integers summing to at most `maxTotal`
/// whose greatest common divisor is 1 (so 2:2 is skipped in favor of 1:1).
func forEachComposition(count: Int, maxTotal: Int, _ body: ([Int]) -> Void) {
    var parts = [Int](repeating: 1, count: count)
    func fill(_ index: Int, remaining: Int, runningGCD: Int) {
        if index == count {
            if runningGCD == 1 { body(parts) }
            return
        }
        let slotsAfter = count - index - 1
        let maxHere = remaining - slotsAfter
        guard maxHere >= 1 else { return }
        for p in 1...maxHere {
            parts[index] = p
            fill(index + 1, remaining: remaining - p, runningGCD: gcd(runningGCD, p))
        }
    }
    fill(0, remaining: maxTotal, runningGCD: 0)
}

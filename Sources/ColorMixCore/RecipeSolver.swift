import Foundation

public struct Solution: Hashable, Sendable {
    public let recipe: Recipe
    public let color: SRGB
    public let deltaE: Double
}

/// Finds the fewest paints, and the ratio between them, that reproduce a target color.
///
/// It tries every combination of 1 to `maxPaints` paints from the palette and every whole-number
/// ratio up to a total number of parts, so the answers are recipes you could actually measure out.
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

    /// The best recipe for each number of paints, keyed by paint count.
    public func bestByPaintCount(for target: SRGB, palette: [Paint]) -> [Int: Solution] {
        let targetLab = target.lab
        let ks = palette.map { $0.reflectance.map(Mixer.kOverS) }
        let bands = Spectral.bandCount
        var best: [Int: (deltaE: Double, indices: [Int], parts: [Int])] = [:]
        var mixed = [Double](repeating: 0, count: bands)

        for k in 1...min(maxPaints, palette.count) {
            let limit = maxTotalParts(paintCount: k)
            for indices in combinations(of: palette.count, choose: k) {
                forEachComposition(count: k, maxTotal: limit) { parts in
                    var total = 0.0
                    for j in 0..<k { total += Double(parts[j]) * palette[indices[j]].strength }
                    for i in 0..<bands { mixed[i] = 0 }
                    for j in 0..<k {
                        let share = Double(parts[j]) * palette[indices[j]].strength / total
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
                    let lab = SRGB(xyz: XYZ(x: x, y: y, z: z)).lab
                    let dE = ColorDifference.deltaE2000(targetLab, lab)
                    if dE < (best[k]?.deltaE ?? .infinity) {
                        best[k] = (dE, indices, parts)
                    }
                }
            }
        }

        var result: [Int: Solution] = [:]
        for (k, entry) in best {
            let recipe = Recipe(zip(entry.indices, entry.parts).map { Ingredient(paint: palette[$0], parts: $1) }).sorted
            result[k] = Solution(recipe: recipe, color: recipe.color ?? target, deltaE: entry.deltaE)
        }
        return result
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
    /// once it's on the palette you can't take it back out. Tries adding up to two paints, in amounts from
    /// a tenth of the current pile up to twice it (beyond that you'd be better off starting a fresh pile).
    /// Returns the best ΔE2000.
    static func bestDeltaEByAdding(to current: Recipe, target: SRGB, palette: [Paint]) -> Double {
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
        let total = Double(current.totalParts)
        let amounts = [0, 0.1, 0.25, 0.5, 1, 1.5, 2].map { $0 * total }

        var best = Double.infinity
        for a in palette.indices {
            for b in a..<palette.count {
                for amountA in amounts {
                    for amountB in (a == b ? [0] : amounts) {
                        let wa = amountA * palette[a].strength
                        let wb = amountB * palette[b].strength
                        let weight = baseWeight + wa + wb
                        var x = 0.0, y = 0.0, z = 0.0
                        for i in 0..<bands {
                            let mixedKS = (baseSum[i] + wa * ks[a][i] + wb * ks[b][i]) / weight
                            let r = Mixer.reflectance(fromKOverS: mixedKS)
                            let w = Spectral.weights[i]
                            x += w.x * r
                            y += w.y * r
                            z += w.z * r
                        }
                        let dE = ColorDifference.deltaE2000(targetLab, SRGB(xyz: XYZ(x: x, y: y, z: z)).lab)
                        best = min(best, dE)
                    }
                }
            }
        }
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

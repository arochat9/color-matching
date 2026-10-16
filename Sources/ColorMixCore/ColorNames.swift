import Foundation

public struct NamedColor: Hashable, Sendable {
    public let name: String
    public let color: SRGB
    public let lab: Lab
}

/// A searchable list of color names. The app ships the ~32k-name list from
/// github.com/meodai/color-names (MIT), dense enough that almost any color has a name within ΔE 2.
public final class ColorNameIndex: @unchecked Sendable {
    public let colors: [NamedColor]

    public init(colors: [NamedColor]) {
        self.colors = colors
    }

    /// Parses "name,hex" lines; a header line and malformed lines are skipped.
    public convenience init(csv: String) {
        var colors: [NamedColor] = []
        csv.enumerateLines { line, _ in
            guard let comma = line.lastIndex(of: ","),
                  let color = SRGB(hex: String(line[line.index(after: comma)...])) else { return }
            let name = String(line[..<comma]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { return }
            colors.append(NamedColor(name: name, color: color, lab: color.lab))
        }
        self.init(colors: colors)
    }

    public func nearest(to color: SRGB) -> (named: NamedColor, deltaE: Double)? {
        let target = color.lab
        var best: (named: NamedColor, deltaE: Double)?
        for candidate in colors {
            // Cheap Euclidean (ΔE76) bound first: ΔE2000 is never far above it for nearby colors.
            let dl = candidate.lab.l - target.l, da = candidate.lab.a - target.a, db = candidate.lab.b - target.b
            if let current = best, dl * dl + da * da + db * db > 9 * current.deltaE * current.deltaE + 25 { continue }
            let dE = ColorDifference.deltaE2000(target, candidate.lab)
            if dE < (best?.deltaE ?? .infinity) { best = (candidate, dE) }
        }
        return best
    }

    public func randomElement<R: RandomNumberGenerator>(using rng: inout R) -> NamedColor? {
        colors.randomElement(using: &rng)
    }
}

/// A sample of colors the palette can mix, used to check quickly whether a goal is reachable.
public struct PaletteGamut: Sendable {
    public let samples: [Lab]

    /// Every mix of up to three paints with up to `maxParts` total parts.
    public init(palette: [Paint], maxParts: Int = 8) {
        var samples: [Lab] = []
        for k in 1...min(3, palette.count) {
            for indices in combinations(of: palette.count, choose: k) {
                forEachComposition(count: k, maxTotal: k == 1 ? 1 : maxParts) { parts in
                    let recipe = Recipe(zip(indices, parts).map { Ingredient(paint: palette[$0], parts: $1) })
                    if let color = recipe.color { samples.append(color.lab) }
                }
            }
        }
        self.samples = samples
    }

    public func distance(to color: SRGB) -> Double {
        let lab = color.lab
        return samples.map { ColorDifference.deltaE2000(lab, $0) }.min() ?? .infinity
    }
}

public extension ChallengeGenerator {
    /// A random named color that the palette can get close to (within `reach` ΔE of a sample mix).
    static func named<R: RandomNumberGenerator>(
        names: ColorNameIndex,
        gamut: PaletteGamut,
        reach: Double = 3,
        using rng: inout R
    ) -> Challenge? {
        var closest: (NamedColor, Double)?
        for _ in 0..<60 {
            guard let candidate = names.randomElement(using: &rng) else { return nil }
            let l = candidate.lab.l
            guard l > 18 && l < 95 else { continue }
            let d = gamut.distance(to: candidate.color)
            if d <= reach { return Challenge(target: candidate.color, name: candidate.name) }
            if d < (closest?.1 ?? .infinity) { closest = (candidate, d) }
        }
        return closest.map { Challenge(target: $0.0.color, name: $0.0.name) }
    }
}

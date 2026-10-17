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

    /// Fractions of the mix (by tinting weight) given to white or black when tinting and shading.
    static let whiteSteps: [Double] = [0, 0.3, 0.5, 0.7, 0.8, 0.88, 0.93, 0.96, 0.98, 0.99, 0.995]
    static let blackSteps: [Double] = [0, 0.003, 0.01, 0.02, 0.05, 0.1, 0.2, 0.4]

    /// Every mix of one or two colored paints (up to `maxParts` parts), each tinted with white and
    /// shaded with black in steps, plus the grays. Small touches of black or a lot of white matter
    /// for pastels and light grays, which coarse whole-number ratios miss.
    public init(palette: [Paint], maxParts: Int = 8) {
        let bands = Spectral.bandCount
        let white = palette.first { $0.id == Paint.titaniumWhite.id }
        let black = palette.first { $0.id == Paint.ivoryBlack.id }
        let colored = palette.filter { $0.id != white?.id && $0.id != black?.id }
        let whiteKS = white?.reflectance.map(Mixer.kOverS)
        let blackKS = black?.reflectance.map(Mixer.kOverS)

        var bases: [[Double]?] = [nil]
        let coloredKS = colored.map { $0.reflectance.map(Mixer.kOverS) }
        for k in 1...min(2, max(colored.count, 1)) where !colored.isEmpty {
            for indices in combinations(of: colored.count, choose: k) {
                forEachComposition(count: k, maxTotal: k == 1 ? 1 : maxParts) { parts in
                    var mixed = [Double](repeating: 0, count: bands)
                    var total = 0.0
                    for (j, index) in indices.enumerated() {
                        let w = Double(parts[j]) * colored[index].strength
                        total += w
                        for i in 0..<bands { mixed[i] += w * coloredKS[index][i] }
                    }
                    bases.append(mixed.map { $0 / total })
                }
            }
        }

        var samples: [Lab] = []
        var ks = [Double](repeating: 0, count: bands)
        for base in bases {
            for wf in (whiteKS == nil ? [0] : PaletteGamut.whiteSteps) {
                for bf in (blackKS == nil ? [0] : PaletteGamut.blackSteps) {
                    let baseShare = 1 - wf - bf
                    if base == nil {
                        // Grays: white and black alone.
                        guard wf + bf > 0, baseShare >= -1e-9 else { continue }
                    } else if baseShare <= 0 {
                        continue
                    }
                    let norm = base == nil ? wf + bf : 1
                    for i in 0..<bands {
                        var v = (base?[i] ?? 0) * max(baseShare, 0)
                        if let whiteKS { v += wf * whiteKS[i] }
                        if let blackKS { v += bf * blackKS[i] }
                        ks[i] = v / norm
                    }
                    let r = ks.map(Mixer.reflectance(fromKOverS:))
                    samples.append(Spectral.srgb(fromReflectance: r).lab)
                }
            }
        }
        self.samples = samples
    }

    /// Closest ΔE2000 from `color` to anything in the gamut.
    public func distance(to color: SRGB) -> Double {
        let lab = color.lab
        // ΔE2000 is slow; shortlist by plain Lab distance first.
        var shortlist: [(Double, Lab)] = []
        shortlist.reserveCapacity(samples.count)
        for s in samples {
            let dl = s.l - lab.l, da = s.a - lab.a, db = s.b - lab.b
            shortlist.append((dl * dl + da * da + db * db, s))
        }
        shortlist.sort { $0.0 < $1.0 }
        return shortlist.prefix(60).map { ColorDifference.deltaE2000(lab, $0.1) }.min() ?? .infinity
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

public extension ColorNameIndex {
    /// The named colors that at least one of `gamuts` can mix to within `reach` ΔE (3 is a 90% match).
    func reachable(by gamuts: [PaletteGamut], within reach: Double = 3) -> [NamedColor] {
        colors.filter { color in gamuts.contains { $0.distance(to: color.color) <= reach } }
    }

    /// How `color` differs from the named color it is closest to, e.g. "lighter, duller".
    /// Returns nil when the difference is too small to mention.
    static func qualifier(of color: Lab, relativeTo named: Lab) -> String? {
        var words: [String] = []
        let dL = color.l - named.l
        if dL > 4 { words.append("lighter") } else if dL < -4 { words.append("darker") }
        let dC = color.chroma - named.chroma
        if dC > 6 { words.append("more vivid") } else if dC < -6 { words.append("duller") }
        if words.isEmpty, ColorDifference.deltaE2000(color, named) > 3 {
            let hue = Scoring.hueFamily(color.hue)
            if Scoring.hueFamily(named.hue) != hue, color.chroma > 8 { words.append("toward \(hue)") }
        }
        return words.isEmpty ? nil : words.joined(separator: ", ")
    }
}

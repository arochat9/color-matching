import Foundation

/// One paint and how many parts of it go into a mix.
public struct Ingredient: Hashable, Sendable {
    public let paint: Paint
    public let parts: Int

    public init(paint: Paint, parts: Int) {
        self.paint = paint
        self.parts = parts
    }
}

/// A list of paints with whole-number parts, like "2 parts red to 1 part yellow".
public struct Recipe: Hashable, Sendable {
    public let ingredients: [Ingredient]

    public init(_ ingredients: [Ingredient]) {
        self.ingredients = ingredients.filter { $0.parts > 0 }
    }

    public var isEmpty: Bool { ingredients.isEmpty }
    public var paintCount: Int { ingredients.count }
    public var totalParts: Int { ingredients.reduce(0) { $0 + $1.parts } }

    /// Share of the mix by volume, 0...1.
    public func fraction(of ingredient: Ingredient) -> Double {
        totalParts == 0 ? 0 : Double(ingredient.parts) / Double(totalParts)
    }

    /// Same ratio with the smallest whole numbers (4:2 becomes 2:1).
    public var simplified: Recipe {
        let divisor = ingredients.map(\.parts).reduce(0, gcd)
        guard divisor > 1 else { return self }
        return Recipe(ingredients.map { Ingredient(paint: $0.paint, parts: $0.parts / divisor) })
    }

    /// Largest share first, which is the order you would actually put paint on the palette.
    public var sorted: Recipe {
        Recipe(ingredients.sorted { $0.parts > $1.parts })
    }

    /// "2 Cadmium Red : 1 Titanium White"
    public var ratioDescription: String {
        ingredients.map { "\($0.parts) \($0.paint.name)" }.joined(separator: " : ")
    }

    public var color: SRGB? { Mixer.color(of: self) }
}

func gcd(_ a: Int, _ b: Int) -> Int {
    var a = abs(a), b = abs(b)
    while b != 0 { (a, b) = (b, a % b) }
    return a
}

/// Subtractive mixing with single-constant Kubelka–Munk theory, applied per wavelength band.
/// Each paint's reflectance R becomes an absorption/scattering ratio K/S = (1 − R)² / 2R;
/// K/S values mix linearly by (parts × tinting strength), and the result converts back to reflectance.
public enum Mixer {
    public static func reflectance(of recipe: Recipe) -> [Double]? {
        let weights = recipe.ingredients.map { Double($0.parts) * $0.paint.strength }
        let total = weights.reduce(0, +)
        guard total > 0 else { return nil }
        var mixed = [Double](repeating: 0, count: Spectral.bandCount)
        for (ingredient, weight) in zip(recipe.ingredients, weights) {
            let share = weight / total
            for i in 0..<Spectral.bandCount {
                mixed[i] += share * kOverS(ingredient.paint.reflectance[i])
            }
        }
        return mixed.map(reflectance(fromKOverS:))
    }

    public static func color(of recipe: Recipe) -> SRGB? {
        reflectance(of: recipe).map(Spectral.srgb(fromReflectance:))
    }

    @inline(__always)
    static func kOverS(_ r: Double) -> Double {
        let r = max(r, 0.001)
        return (1 - r) * (1 - r) / (2 * r)
    }

    @inline(__always)
    static func reflectance(fromKOverS ks: Double) -> Double {
        1 + ks - (ks * ks + 2 * ks).squareRoot()
    }
}

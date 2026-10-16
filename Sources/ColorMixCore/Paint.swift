import Foundation

/// A tube of paint: a reflectance curve plus a tinting strength (how hard it pushes a mix per part).
public struct Paint: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let note: String
    public let reflectance: [Double]
    public let strength: Double
    /// How the paint looks straight out of the tube.
    public let color: SRGB

    public init(id: String, name: String, note: String, strength: Double = 1, reflectance: [Double]) {
        self.id = id
        self.name = name
        self.note = note
        self.strength = strength
        self.reflectance = reflectance
        self.color = Spectral.srgb(fromReflectance: reflectance)
    }
}

public extension Paint {
    static let titaniumWhite = Paint(
        id: "titanium-white", name: "Titanium White", note: "Lightens and cools",
        reflectance: Spectral.curve { _ in 0.92 }
    )

    static let ivoryBlack = Paint(
        id: "ivory-black", name: "Ivory Black", note: "Darkens; with yellow it makes olive greens",
        reflectance: Spectral.curve { _ in 0.025 }
    )

    static let cadmiumYellow = Paint(
        id: "cadmium-yellow", name: "Cadmium Yellow", note: "Warm primary yellow",
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 515, width: 12, low: 0.04, high: 0.88) }
    )

    static let cadmiumRed = Paint(
        id: "cadmium-red", name: "Cadmium Red", note: "Warm primary red",
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 600, width: 10, low: 0.04, high: 0.80) }
    )

    static let ultramarineBlue = Paint(
        id: "ultramarine-blue", name: "Ultramarine Blue", note: "Warm, slightly violet primary blue",
        reflectance: Spectral.curve {
            0.03 + 0.45 * Spectral.lobe($0, center: 450, left: 22, right: 32)
                + Spectral.sigmoid($0, center: 665, width: 12, low: 0, high: 0.2)
        }
    )

    static let yellowOchre = Paint(
        id: "yellow-ochre", name: "Yellow Ochre", note: "Earthy, muted yellow; weak tinter",
        strength: 0.5,
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 540, width: 25, low: 0.08, high: 0.62) }
    )

    static let burntUmber = Paint(
        id: "burnt-umber", name: "Burnt Umber", note: "Dark warm brown; tames bright colors",
        strength: 0.8,
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 600, width: 40, low: 0.04, high: 0.22) }
    )
}

/// A starting set of paints, the way painters set up a palette.
public struct Palette: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let paints: [Paint]

    public init(id: String, name: String, summary: String, paints: [Paint]) {
        self.id = id
        self.name = name
        self.summary = summary
        self.paints = paints
    }
}

public extension Palette {
    /// The classic beginner's limited palette: the three primaries plus white, black and two earths.
    static let limited = Palette(
        id: "limited",
        name: "Limited palette",
        summary: "Primaries + white, black, ochre and umber. The usual starting kit.",
        paints: [.titaniumWhite, .ivoryBlack, .cadmiumYellow, .cadmiumRed, .ultramarineBlue, .yellowOchre, .burntUmber]
    )

    static let primaries = Palette(
        id: "primaries",
        name: "Primaries",
        summary: "Red, yellow, blue, white and black only.",
        paints: [.titaniumWhite, .ivoryBlack, .cadmiumYellow, .cadmiumRed, .ultramarineBlue]
    )

    /// Anders Zorn's famous four-color palette, great for skin tones.
    static let zorn = Palette(
        id: "zorn",
        name: "Zorn palette",
        summary: "White, black, ochre and red. Black plays the role of blue.",
        paints: [.titaniumWhite, .ivoryBlack, .yellowOchre, .cadmiumRed]
    )

    static let all: [Palette] = [.limited, .primaries, .zorn]
}

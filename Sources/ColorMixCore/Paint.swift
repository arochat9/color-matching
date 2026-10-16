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

    static let phthaloBlue = Paint(
        id: "phthalo-blue", name: "Phthalo Blue", note: "Very strong, clean cyan-leaning blue",
        strength: 1.6,
        reflectance: Spectral.curve {
            0.015 + 0.42 * Spectral.lobe($0, center: 468, left: 22, right: 36)
                + Spectral.sigmoid($0, center: 680, width: 10, low: 0, high: 0.03)
        }
    )

    static let quinacridoneMagenta = Paint(
        id: "quinacridone-magenta", name: "Quinacridone Magenta", note: "Clean cool magenta for pinks and purples",
        strength: 1.2,
        reflectance: Spectral.curve {
            Spectral.sigmoid($0, center: 605, width: 14, low: 0.03, high: 0.72)
                + 0.32 * Spectral.lobe($0, center: 405, left: 20, right: 25)
        }
    )

    static let lemonYellow = Paint(
        id: "lemon-yellow", name: "Lemon Yellow", note: "Cool yellow for bright greens",
        strength: 0.9,
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 495, width: 11, low: 0.05, high: 0.9) }
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
    /// The standard beginner's palette: the three primaries plus white, black and two earths.
    static let limited = Palette(
        id: "limited",
        name: "Standard palette",
        summary: "Primaries + white, black, ochre and umber. The usual starting kit.",
        paints: [.titaniumWhite, .ivoryBlack, .cadmiumYellow, .cadmiumRed, .ultramarineBlue, .yellowOchre, .burntUmber]
    )

    /// The limited palette plus three vivid tubes, for clean greens, pinks and purples.
    static let extended = Palette(
        id: "extended",
        name: "Extended palette",
        summary: "Standard palette plus phthalo blue, quinacridone magenta and lemon yellow.",
        paints: Palette.limited.paints + [.phthaloBlue, .quinacridoneMagenta, .lemonYellow]
    )

    static let all: [Palette] = [.limited, .extended]
}

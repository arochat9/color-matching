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
        id: "titanium-white", name: "White", note: "Titanium white: lightens and cools",
        reflectance: Spectral.curve { _ in 0.92 }
    )

    static let ivoryBlack = Paint(
        id: "ivory-black", name: "Black", note: "Ivory black: darkens; with yellow it makes olive greens",
        reflectance: Spectral.curve { 0.016 + Spectral.sigmoid($0, center: 600, width: 40, low: 0, high: 0.004) }
    )

    static let cadmiumYellow = Paint(
        id: "cadmium-yellow", name: "Yellow", note: "Cadmium yellow: warm primary yellow",
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 515, width: 12, low: 0.04, high: 0.88) }
    )

    static let cadmiumRed = Paint(
        id: "cadmium-red", name: "Red", note: "Cadmium red: warm primary red",
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
        id: "phthalo-blue", name: "Blue", note: "Phthalo blue: very strong, clean cyan-leaning blue",
        strength: 1.6,
        reflectance: Spectral.curve {
            0.015 + 0.42 * Spectral.lobe($0, center: 468, left: 22, right: 36)
                + Spectral.sigmoid($0, center: 680, width: 10, low: 0, high: 0.03)
        }
    )

    static let quinacridoneMagenta = Paint(
        id: "quinacridone-magenta", name: "Magenta", note: "Quinacridone magenta: clean cool magenta for pinks and purples",
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

    static let cadmiumOrange = Paint(
        id: "cadmium-orange", name: "Cadmium Orange", note: "Clean warm orange",
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 580, width: 10, low: 0.04, high: 0.85) }
    )

    static let permanentRose = Paint(
        id: "permanent-rose", name: "Permanent Rose", note: "Cool pink-red for roses and pinks",
        strength: 1.1,
        reflectance: Spectral.curve {
            Spectral.sigmoid($0, center: 612, width: 12, low: 0.03, high: 0.78) + 0.18 * Spectral.lobe($0, center: 410, left: 20, right: 25)
        }
    )

    static let dioxazinePurple = Paint(
        id: "dioxazine-purple", name: "Dioxazine Purple", note: "Deep, strong purple",
        strength: 1.5,
        reflectance: Spectral.curve {
            0.02 + 0.22 * Spectral.lobe($0, center: 425, left: 25, right: 20) + Spectral.sigmoid($0, center: 660, width: 15, low: 0, high: 0.35)
        }
    )

    static let ceruleanBlue = Paint(
        id: "cerulean-blue", name: "Cerulean Blue", note: "Sky blue that leans green",
        strength: 0.7,
        reflectance: Spectral.curve {
            0.06 + 0.5 * Spectral.lobe($0, center: 485, left: 30, right: 40) + Spectral.sigmoid($0, center: 690, width: 15, low: 0, high: 0.1)
        }
    )

    static let cobaltBlue = Paint(
        id: "cobalt-blue", name: "Cobalt Blue", note: "Pure mid blue",
        strength: 0.8,
        reflectance: Spectral.curve {
            0.04 + 0.55 * Spectral.lobe($0, center: 460, left: 25, right: 30) + Spectral.sigmoid($0, center: 685, width: 15, low: 0, high: 0.15)
        }
    )

    static let phthaloGreen = Paint(
        id: "phthalo-green", name: "Phthalo Green", note: "Very strong cool green",
        strength: 1.6,
        reflectance: Spectral.curve { 0.02 + 0.45 * Spectral.lobe($0, center: 510, left: 25, right: 30) }
    )

    static let viridian = Paint(
        id: "viridian", name: "Viridian", note: "Cool, slightly blue green",
        strength: 0.7,
        reflectance: Spectral.curve { 0.05 + 0.4 * Spectral.lobe($0, center: 505, left: 30, right: 35) }
    )

    static let burntSienna = Paint(
        id: "burnt-sienna", name: "Burnt Sienna", note: "Warm orange-brown",
        strength: 0.8,
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 590, width: 30, low: 0.05, high: 0.45) }
    )

    static let alizarinCrimson = Paint(
        id: "alizarin-crimson", name: "Alizarin Crimson", note: "Deep cool red",
        reflectance: Spectral.curve {
            Spectral.sigmoid($0, center: 620, width: 15, low: 0.02, high: 0.6) + 0.08 * Spectral.lobe($0, center: 420, left: 20, right: 20)
        }
    )

    static let naplesYellow = Paint(
        id: "naples-yellow", name: "Naples Yellow", note: "Soft, pale warm yellow",
        strength: 0.5,
        reflectance: Spectral.curve { Spectral.sigmoid($0, center: 500, width: 30, low: 0.35, high: 0.88) }
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

/// A fixed core of six tubes, plus one tube picked for each goal: the one that gets closest to it.
/// This is how painters work: a small everyday palette, and a specialty tube when a subject needs it.
public enum DynamicPalette {
    public static let core: [Paint] = [.titaniumWhite, .ivoryBlack, .cadmiumYellow, .cadmiumRed, .phthaloBlue, .quinacridoneMagenta]

    /// Candidates for the seventh tube.
    public static let extras: [Paint] = [
        .ultramarineBlue, .cadmiumOrange, .alizarinCrimson, .yellowOchre, .burntSienna, .permanentRose, .naplesYellow,
        .burntUmber, .dioxazinePurple, .ceruleanBlue, .cobaltBlue, .phthaloGreen, .lemonYellow, .viridian,
    ]

    /// Every tube you can put on your palette.
    public static let allPaints: [Paint] = core + extras

    public static func palette(with extra: Paint) -> Palette {
        Palette(id: "dynamic-\(extra.id)", name: "Core + \(extra.name)", summary: "", paints: core + [extra])
    }
}


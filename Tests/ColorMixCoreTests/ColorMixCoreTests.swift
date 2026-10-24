import XCTest
@testable import ColorMixCore

final class ColorSpaceTests: XCTestCase {
    func testHexRoundTrip() {
        let color = SRGB(hex: "#3C5756")
        XCTAssertEqual(color?.hex, "#3C5756")
        XCTAssertNil(SRGB(hex: "nope"))
    }

    func testLabRoundTripThroughXYZ() {
        let color = SRGB(hex: "#D5392E")!
        XCTAssertEqual(SRGB(xyz: color.xyz).hex, color.hex)
    }

    // Reference pairs from Sharma, Wu & Dalal, "The CIEDE2000 Color-Difference Formula" (2005).
    func testDeltaE2000ReferenceValues() {
        XCTAssertEqual(ColorDifference.deltaE2000(Lab(l: 50, a: 2.6772, b: -79.7751), Lab(l: 50, a: 0, b: -82.7485)), 2.0425, accuracy: 1e-4)
        XCTAssertEqual(ColorDifference.deltaE2000(Lab(l: 50, a: 2.5, b: 0), Lab(l: 73, a: 25, b: -18)), 27.1492, accuracy: 1e-4)
        XCTAssertEqual(ColorDifference.deltaE2000(Lab(l: 50, a: 2.5, b: 0), Lab(l: 50, a: 0, b: -2.5)), 4.3065, accuracy: 1e-4)
    }

    func testPerfectReflectorIsWhite() {
        let white = Spectral.srgb(fromReflectance: Spectral.curve { _ in 1 })
        XCTAssertEqual(white.lab.l, 100, accuracy: 0.5)
        XCTAssertLessThan(white.lab.chroma, 1)
    }
}

final class MixerTests: XCTestCase {
    func mix(_ pairs: (Paint, Int)...) -> Lab {
        Recipe(pairs.map { Ingredient(paint: $0.0, parts: $0.1) }).color!.lab
    }

    func testSinglePaintMixesToItself() {
        let lab = mix((.cadmiumRed, 3))
        XCTAssertLessThan(ColorDifference.deltaE2000(lab, Paint.cadmiumRed.color.lab), 0.5)
    }

    func testBlueAndYellowMakeGreen() {
        let lab = mix((.ultramarineBlue, 1), (.cadmiumYellow, 2))
        XCTAssertLessThan(lab.a, -5, "should lean green, not gray")
    }

    func testYellowAndBlackMakeOlive() {
        let lab = mix((.cadmiumYellow, 1), (.ivoryBlack, 1))
        XCTAssertLessThan(lab.a, 0)
        XCTAssertGreaterThan(lab.b, 0)
    }

    func testWhiteLightensRed() {
        XCTAssertGreaterThan(mix((.cadmiumRed, 1), (.titaniumWhite, 2)).l, Paint.cadmiumRed.color.lab.l + 5)
    }

    func testRedAndYellowMakeOrange() {
        let hue = mix((.cadmiumRed, 1), (.cadmiumYellow, 1)).hue
        XCTAssertEqual(Scoring.hueFamily(hue), "orange")
    }

    func testRecipeSimplifies() {
        let recipe = Recipe([Ingredient(paint: .cadmiumRed, parts: 4), Ingredient(paint: .titaniumWhite, parts: 2)])
        XCTAssertEqual(recipe.simplified.ingredients.map(\.parts), [2, 1])
    }
}

final class SolverTests: XCTestCase {
    func testCompositionsSkipNonReducedRatios() {
        var seen: [[Int]] = []
        forEachComposition(count: 2, maxTotal: 4) { seen.append($0) }
        XCTAssertEqual(seen, [[1, 1], [1, 2], [1, 3], [2, 1], [3, 1]])
    }

    func testFindsSinglePaint() {
        let solved = RecipeSolver().solve(for: Paint.ultramarineBlue.color, palette: Palette.limited.paints)!
        XCTAssertEqual(solved.simplest.recipe.paintCount, 1)
        XCTAssertEqual(solved.simplest.recipe.ingredients.first?.paint.id, Paint.ultramarineBlue.id)
    }

    func testRecoversKnownTwoPaintMix() {
        let source = Recipe([Ingredient(paint: .cadmiumRed, parts: 2), Ingredient(paint: .cadmiumYellow, parts: 1)])
        let solved = RecipeSolver().solve(for: source.color!, palette: Palette.limited.paints)!
        XCTAssertLessThanOrEqual(solved.simplest.recipe.paintCount, 2)
        XCTAssertLessThan(solved.simplest.deltaE, 1)
    }

    func testFindsADropOfBlackInABigPile() {
        // Far finer than the coarse search's ratios: only the drop-by-drop refinement finds it.
        let source = Recipe([Ingredient(paint: .cadmiumYellow, parts: 60), Ingredient(paint: .ivoryBlack, parts: 1)])
        let solved = RecipeSolver().solve(for: source.color!, palette: DynamicPalette.core)!
        XCTAssertLessThan(solved.closest.deltaE, 1)
        XCTAssertLessThanOrEqual(solved.closest.recipe.totalParts, RecipeSolver.maxPileParts)
    }

    func testGeneratedChallengesAreSolvable() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<5 {
            let challenge = ChallengeGenerator.reachable(palette: Palette.limited.paints, using: &rng)
            let solved = RecipeSolver().solve(for: challenge.target, palette: Palette.limited.paints)!
            XCTAssertLessThan(solved.closest.deltaE, 1.5)
        }
    }
}

final class ScoringTests: XCTestCase {
    func testPercentMapping() {
        XCTAssertEqual(Scoring.matchPercent(deltaE: 0), 100)
        XCTAssertEqual(Scoring.matchPercent(deltaE: 3), 90, accuracy: 1e-9)
        XCTAssertEqual(Scoring.matchPercent(deltaE: 45), 0)
    }

    func testFeedbackSaysTooLight() {
        let notes = Scoring.feedback(target: Lab(l: 40, a: 0, b: 0), guess: Lab(l: 60, a: 0, b: 0))
        XCTAssertTrue(notes.contains { $0.hasPrefix("Too light") })
    }

    func testSeededRNGIsDeterministic() {
        var a = SplitMix64(seed: 7), b = SplitMix64(seed: 7)
        XCTAssertEqual(a.next(), b.next())
    }
}

final class ColorNameTests: XCTestCase {
    let index = ColorNameIndex(csv: """
    name,hex
    Cerulean,#007BA7
    Lemon Yellow,#FFF44F
    Teal,#008080
    not a color
    """)

    func testParsesAndSkipsBadLines() {
        XCTAssertEqual(index.colors.map(\.name), ["Cerulean", "Lemon Yellow", "Teal"])
    }

    func testNearestName() {
        XCTAssertEqual(index.nearest(to: SRGB(hex: "#0A7DA5")!)?.named.name, "Cerulean")
        XCTAssertEqual(index.nearest(to: SRGB(hex: "#FFF000")!)?.named.name, "Lemon Yellow")
    }

    func testNamedChallengeIsWithinReach() {
        let gamut = PaletteGamut(palette: Palette.limited.paints)
        var rng = SplitMix64(seed: 3)
        let challenge = ChallengeGenerator.named(names: index, gamut: gamut, reach: 100, using: &rng)
        XCTAssertNotNil(challenge?.name)
    }
}

final class GoalPoolTests: XCTestCase {
    /// The app's real list of painter colors.
    static let paintColors: ColorNameIndex = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("App/Resources/paintcolors.csv")
        return ColorNameIndex(csv: (try? String(contentsOf: url, encoding: .utf8)) ?? "")
    }()

    func testDefaultPaletteDealsOnlyReachableColors() {
        let names = GoalPoolTests.paintColors
        let gamuts = DynamicPalette.extras.map { PaletteGamut(palette: DynamicPalette.palette(with: $0).paints) }
        let pool = names.reachable(by: gamuts)
        print("Goal pool: \(pool.count) of \(names.colors.count) colors")
        XCTAssertGreaterThan(pool.count, names.colors.count / 2)
        XCTAssertLessThan(pool.count, names.colors.count)
    }

    func testSmallerPaletteHasASmallerPool() {
        let names = GoalPoolTests.paintColors
        let full = names.reachable(by: [PaletteGamut(palette: DynamicPalette.core)])
        let twoTubes = names.reachable(by: [PaletteGamut(palette: [.titaniumWhite, .ultramarineBlue])])
        XCTAssertLessThan(twoTubes.count, full.count)
    }
}

final class QualifierTests: XCTestCase {
    func testLighterAndDuller() {
        let named = Lab(l: 50, a: 40, b: 0)
        XCTAssertEqual(ColorNameIndex.qualifier(of: Lab(l: 60, a: 20, b: 0), relativeTo: named), "lighter, duller")
        XCTAssertNil(ColorNameIndex.qualifier(of: Lab(l: 51, a: 41, b: 0), relativeTo: named))
    }
}

final class RecoveryTests: XCTestCase {
    func testCanRecoverByAddingMoreOfTheMissingPaint() {
        let target = Recipe([Ingredient(paint: .cadmiumRed, parts: 1), Ingredient(paint: .titaniumWhite, parts: 1)]).color!
        let current = Recipe([Ingredient(paint: .cadmiumRed, parts: 1)])
        XCTAssertLessThan(RecipeSolver.bestDeltaEByAdding(to: current, target: target, palette: Palette.limited.paints), 1)
    }

    func testOnePartOfTheExtraTubeIsNotPastNoReturn() {
        // The original report: one part of rose toward a brick red was flagged though it's easy to fix.
        let palette = DynamicPalette.palette(with: .permanentRose).paints
        let current = Recipe([Ingredient(paint: .permanentRose, parts: 1)])
        XCTAssertLessThan(RecipeSolver.bestDeltaEByAdding(to: current, target: SRGB(hex: "#B0513A")!, palette: palette), 3)
    }

    func testBlackInYellowCannotBeUndone() {
        // Black dulls yellow for good.
        let target = Paint.cadmiumYellow.color
        let current = Recipe([Ingredient(paint: .ivoryBlack, parts: 1), Ingredient(paint: .cadmiumYellow, parts: 2)])
        XCTAssertGreaterThan(RecipeSolver.bestDeltaEByAdding(to: current, target: target, palette: Palette.limited.paints), 3)
    }

    func testTriplingThePileIsTheLimit() {
        // A screenshot from play: white and black in a cobalt blue. Tripling the pile can't save it,
        // but about 20 more white and 30 more ultramarine (11 times the pile) would.
        let target = SRGB(hex: "#1F4FA8")!
        let current = Recipe([
            Ingredient(paint: .titaniumWhite, parts: 1), Ingredient(paint: .ivoryBlack, parts: 1),
            Ingredient(paint: .phthaloBlue, parts: 2), Ingredient(paint: .ultramarineBlue, parts: 1),
        ])
        let palette = DynamicPalette.core + [Paint.ultramarineBlue]
        XCTAssertGreaterThan(RecipeSolver.bestDeltaEByAdding(to: current, target: target, palette: palette), 3)
        XCTAssertLessThan(RecipeSolver.bestDeltaEByAdding(to: current, target: target, palette: palette, maxGrowth: 12), 3)
    }

    func testLightGraysAndPastelsAreInReach() {
        // A touch of black in a lot of white: coarse whole-number ratios used to miss these.
        XCTAssertLessThan(PaletteGamut(palette: Palette.limited.paints).distance(to: SRGB(hex: "#C0C0C0")!), 2)
        XCTAssertLessThan(PaletteGamut(palette: Palette.extended.paints).distance(to: SRGB(hex: "#B0E0E6")!), 1)
    }

    func testDynamicPaletteReachesCeruleanWithOneExtraTube() {
        let cerulean = SRGB(hex: "#2A7DB8")!
        let best = DynamicPalette.extras
            .map { PaletteGamut(palette: DynamicPalette.palette(with: $0).paints).distance(to: cerulean) }
            .min()!
        XCTAssertLessThan(best, 3)
        XCTAssertEqual(DynamicPalette.palette(with: .ultramarineBlue).paints.count, 7)
    }

    func testExtendedPaletteReachesBrighterGreens() {
        let green = SRGB(hex: "#15B01A")!
        let limited = PaletteGamut(palette: Palette.limited.paints).distance(to: green)
        let extended = PaletteGamut(palette: Palette.extended.paints).distance(to: green)
        XCTAssertLessThan(extended, limited)
    }
}

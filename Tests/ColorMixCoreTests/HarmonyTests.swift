import XCTest
@testable import ColorMixCore

final class ColorWheelTests: XCTestCase {
    func testPainterWheelPrimaries() {
        XCTAssertEqual(WheelColor(hue: 0, saturation: 1, brightness: 1).srgb.hex, "#FF0000")
        XCTAssertEqual(WheelColor(hue: 120, saturation: 1, brightness: 1).srgb.hex, "#FFFF00")
        XCTAssertEqual(WheelColor(hue: 180, saturation: 1, brightness: 1).srgb.hex, "#00FF00")
        XCTAssertEqual(ColorWheel.name(forHue: 180), "green")
        XCTAssertEqual(ColorWheel.name(forHue: 59), "orange")
    }

    func testHueMappingRoundTrips() {
        for hue in stride(from: 0.0, to: 360, by: 7) {
            XCTAssertEqual(ColorWheel.rybHue(fromRGB: ColorWheel.rgbHue(fromRYB: hue)), hue, accuracy: 1e-9)
        }
    }

    func testSignedDistanceWrapsAround() {
        XCTAssertEqual(ColorWheel.signedDistance(from: 350, to: 10), 20)
        XCTAssertEqual(ColorWheel.signedDistance(from: 10, to: 350), -20)
    }
}

final class HarmonyTests: XCTestCase {
    func testRedAndGreenAreComplementary() {
        let best = Harmony.bestFit(hues: [0, 180])
        XCTAssertEqual(best.rule, .complementary)
        XCTAssertEqual(best.error, 0, accuracy: 1e-9)
    }

    func testTriadIsRecognizedAcrossTheWrap() {
        let best = Harmony.bestFit(hues: [350, 110, 230])
        XCTAssertEqual(best.rule, .triadic)
        XCTAssertEqual(best.error, 0, accuracy: 1e-9)
    }

    func testNearIdenticalHuesAreNotAHarmony() {
        XCTAssertGreaterThan(Harmony.fit(hues: [0, 4, 8], rule: .complementary), 30)
    }

    func testFitPuzzlesHaveExactlyOneFittingOption() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<200 {
            let puzzle = FitPuzzle.make(using: &rng)
            XCTAssertEqual(puzzle.options.count, 5)
            XCTAssertEqual(puzzle.options.filter { $0.kind == .answer }.count, 1)
            let shown = puzzle.shown.map(\.hue)
            XCTAssertLessThan(Harmony.fit(hues: shown + [puzzle.answer.color.hue], rule: puzzle.rule), 7)
            for option in puzzle.options where option.kind == .offHue {
                XCTAssertGreaterThanOrEqual(Harmony.bestFit(hues: shown + [option.color.hue]).error, FitPuzzle.offHueMinimum)
            }
            for option in puzzle.options where option.kind == .offTone {
                XCTAssertNotEqual(Tone.nearest(to: option.color), puzzle.tone)
            }
            // All five come from one hue family, so you're picking a shade, not a hue.
            for option in puzzle.options {
                XCTAssertLessThanOrEqual(ColorWheel.distance(option.color.hue, puzzle.family.center), 45.5)
            }
        }
    }

    func testHuePuzzleGrading() {
        var rng = SplitMix64(seed: 7)
        for _ in 0..<100 {
            let puzzle = HuePuzzle.make(using: &rng)
            XCTAssertTrue(puzzle.family.range.contains(puzzle.target.hue) || puzzle.family.range.contains(puzzle.target.hue - 360))
            XCTAssertEqual(puzzle.grade(puzzle.target).percent, 100, accuracy: 1e-9)
            let opposite = WheelColor(hue: puzzle.target.hue + 90, saturation: 1 - puzzle.target.saturation, brightness: 1 - puzzle.target.brightness)
            XCTAssertLessThan(puzzle.grade(opposite).percent, 30)
        }
    }

    func testHueTipsPointTheRightWay() {
        let puzzle = HuePuzzle(rule: .complementary, tone: .vivid, shown: [Tone.vivid.color(hue: 0)], target: Tone.vivid.color(hue: 180))
        let grade = puzzle.grade(Tone.vivid.color(hue: 200))
        XCTAssertEqual(grade.tips.first, "Your hue is 20° too far toward blue-green.")
        XCTAssertEqual(grade.tips.last, "The tone matches the set.")
    }
}

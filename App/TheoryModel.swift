import SwiftUI

/// State for the color theory tab: a "best fit" quiz and a "find the hue" quiz.
final class TheoryModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case fit, hue
        var id: String { rawValue }
        var title: String {
            switch self {
            case .fit: "Best fit"
            case .hue: "Find the hue"
            }
        }
    }

    @Published var mode: Mode = .fit

    @Published private(set) var fitPuzzle: FitPuzzle
    /// The option you tapped, once you've answered.
    @Published private(set) var fitPick: FitPuzzle.Option?
    /// Best-fit answers in a row.
    @Published private(set) var streak = 0

    @Published private(set) var huePuzzle: HuePuzzle
    @Published var pick: WheelColor
    @Published private(set) var hueGrade: HueGrade?

    private var rng: SplitMix64

    init(seed: UInt64? = nil) {
        var rng = SplitMix64(seed: seed ?? UInt64.random(in: 0...UInt64.max))
        fitPuzzle = FitPuzzle.make(using: &rng)
        let hue = HuePuzzle.make(using: &rng)
        huePuzzle = hue
        pick = TheoryModel.startingPick(for: hue)
        self.rng = rng
    }

    /// The picker starts in the middle of the family, half saturated, so it gives nothing away.
    private static func startingPick(for puzzle: HuePuzzle) -> WheelColor {
        WheelColor(hue: puzzle.family.center, saturation: 0.5, brightness: 0.75)
    }

    func choose(_ option: FitPuzzle.Option) {
        guard fitPick == nil else { return }
        fitPick = option
        streak = option.kind == .answer ? streak + 1 : 0
    }

    func nextFit() {
        fitPick = nil
        fitPuzzle = FitPuzzle.make(using: &rng)
    }

    func submitHue() {
        hueGrade = huePuzzle.grade(pick)
    }

    func nextHue() {
        hueGrade = nil
        huePuzzle = HuePuzzle.make(using: &rng)
        pick = TheoryModel.startingPick(for: huePuzzle)
    }
}

extension WheelColor {
    var swiftUIColor: Color { srgb.swiftUIColor }
}

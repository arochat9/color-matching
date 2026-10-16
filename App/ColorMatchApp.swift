import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var model = ColorMatchApp.makeModel()
    @StateObject private var theory = ColorMatchApp.makeTheoryModel()
    @State private var tab = UserDefaults.standard.string(forKey: "demo")?.hasPrefix("theory") == true ? Tab.theory : .mix

    enum Tab { case mix, theory }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                ContentView(model: model)
                    .tabItem { Label("Mix", systemImage: "paintbrush.pointed.fill") }
                    .tag(Tab.mix)
                TheoryView(model: theory)
                    .tabItem { Label("Theory", systemImage: "camera.filters") }
                    .tag(Tab.theory)
            }
            .themed(.sketchbook)
        }
    }

    /// `-demo theory-fit|theory-fit-answered|theory-hue|theory-hue-answered` and `-seed N`, for CI screenshots.
    private static func makeTheoryModel() -> TheoryModel {
        let defaults = UserDefaults.standard
        guard let demo = defaults.string(forKey: "demo"), demo.hasPrefix("theory") else { return TheoryModel() }
        let model = TheoryModel(seed: UInt64(max(defaults.integer(forKey: "seed"), 1)))
        if demo.hasPrefix("theory-hue") {
            model.mode = .hue
            // Close but not quite, so the result shows tips.
            let target = model.huePuzzle.target
            model.pick = WheelColor(hue: target.hue + 14, saturation: target.saturation - 0.15, brightness: target.brightness + 0.05)
            if demo == "theory-hue-answered" { model.submitHue() }
        } else if demo == "theory-fit-answered", let wrong = model.fitPuzzle.options.first(where: { $0.kind == .offTone }) {
            model.choose(wrong)
        }
        return model
    }

    /// Launch arguments used by CI to take repeatable screenshots:
    /// `-demo mixing|submitted|drops|library|noreturn|neon` and `-seed N`. "drops" is played by ContentView.
    private static func makeModel() -> GameModel {
        let defaults = UserDefaults.standard
        guard let demo = defaults.string(forKey: "demo") else { return GameModel() }
        let seed = UInt64(max(defaults.integer(forKey: "seed"), 1))
        let model = GameModel(seed: seed, persistScore: false)
        if defaults.string(forKey: "goalMode") == nil {
            // Screenshots of the mixing screen read best with a goal the palette can actually hit.
            var rng = SplitMix64(seed: seed)
            model.setDemoChallenge(ChallengeGenerator.reachable(palette: model.palette.paints, using: &rng))
        }
        if demo != "drops", let source = model.challenge.sourceRecipe {
            // Start from the true recipe, then nudge it so the demo shows a near miss with feedback.
            var ingredients = source.ingredients
            if let first = ingredients.first {
                ingredients[0] = Ingredient(paint: first.paint, parts: first.parts + 1)
            }
            model.setParts(Recipe(ingredients))
        }
        if demo == "noreturn" {
            // Far too much white for straight-from-the-tube ultramarine: shows the point-of-no-return warning.
            let ultramarine = Recipe([Ingredient(paint: .ultramarineBlue, parts: 1)])
            model.setDemoChallenge(Challenge(target: Paint.ultramarineBlue.color, sourceRecipe: ultramarine))
            model.setParts(Recipe([Ingredient(paint: .ultramarineBlue, parts: 1), Ingredient(paint: .titaniumWhite, parts: 12)]))
        }
        if demo == "neon", let neon = GameModel.colorNames.colors.first(where: { $0.name == "Green Gold" }) {
            model.practice(neon)
        }
        if demo == "submitted" {
            model.submit()
        }
        return model
    }
}

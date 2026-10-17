import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var model = ColorMatchApp.makeModel()
    @StateObject private var theory = ColorMatchApp.makeTheoryModel()
    @State private var game = ColorMatchApp.demoGame

    var body: some Scene {
        WindowGroup {
            HomeView(model: model, theory: theory, onPlay: { game = $0 }, howTo: ColorMatchApp.demoHowTo)
                .fullScreenCover(item: $game) { game in
                    Group {
                        switch game {
                        case .mix: ContentView(model: model, onHome: { self.game = nil })
                        case .theory: TheoryView(model: theory, onHome: { self.game = nil })
                        }
                    }
                    .themed(.sketchbook)
                }
                .themed(.sketchbook)
        }
    }

    /// CI screenshots open straight into a game: theory demos into Color Theory, the rest into mixing.
    /// `-demo home` shows the home page, and `-demo howto-mix|howto-theory` its how-to-play sheet.
    private static var demoGame: Game? {
        guard let demo = UserDefaults.standard.string(forKey: "demo") else { return nil }
        if demo == "home" || demo.hasPrefix("howto") { return nil }
        return demo.hasPrefix("theory") ? .theory : .mix
    }

    private static var demoHowTo: Game? {
        switch UserDefaults.standard.string(forKey: "demo") {
        case "howto-mix": .mix
        case "howto-theory": .theory
        default: nil
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
    /// `-demo mixing|submitted|success|drops|library|paints|noreturn|neon` and `-seed N`. "drops" is played by ContentView.
    private static func makeModel() -> GameModel {
        let defaults = UserDefaults.standard
        guard let demo = defaults.string(forKey: "demo") else { return GameModel() }
        let seed = UInt64(max(defaults.integer(forKey: "seed"), 1))
        let model = GameModel(seed: seed, persistScore: false)
        // Screenshots read best with a goal the palette can hit: the named color nearest a mix it can make.
        var rng = SplitMix64(seed: seed)
        let mix = ChallengeGenerator.reachable(palette: model.palette.paints, using: &rng)
        if let nearest = GameModel.colorNames.nearest(to: mix.target) {
            model.setDemoChallenge(Challenge(target: nearest.named.color, sourceRecipe: mix.sourceRecipe, name: nearest.named.name))
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
            // Black in a bright yellow can't be cleaned up by adding paint: shows the point-of-no-return warning.
            let yellow = Recipe([Ingredient(paint: .cadmiumYellow, parts: 1)])
            model.setDemoChallenge(Challenge(target: Paint.cadmiumYellow.color, sourceRecipe: yellow))
            model.setParts(Recipe([Ingredient(paint: .ivoryBlack, parts: 1), Ingredient(paint: .cadmiumYellow, parts: 2)]))
        }
        if demo == "neon", let neon = GameModel.colorNames.colors.first(where: { $0.name == "Green Gold" }) {
            model.practice(neon)
        }
        if demo == "success", let best = RecipeSolver().solve(for: model.challenge.target, palette: model.palette.paints)?.closest {
            // The best mix the palette can make, so the result screen shows a win.
            model.setParts(best.recipe)
            model.submit()
        }
        if demo == "submitted" {
            model.submit()
        }
        return model
    }
}

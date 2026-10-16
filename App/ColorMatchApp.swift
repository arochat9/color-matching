import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var model = ColorMatchApp.makeModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .themed(.sketchbook)
        }
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

import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var model = ColorMatchApp.makeModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
        }
    }

    /// Launch arguments used by CI to take repeatable screenshots:
    /// `-demo mixing|submitted` and `-seed N`.
    private static func makeModel() -> GameModel {
        let defaults = UserDefaults.standard
        guard let demo = defaults.string(forKey: "demo") else { return GameModel() }
        let seed = UInt64(max(defaults.integer(forKey: "seed"), 1))
        let model = GameModel(seed: seed, persistScore: false)
        if let source = model.challenge.sourceRecipe {
            // Start from the true recipe, then nudge it so the demo shows a near miss with feedback.
            var ingredients = source.ingredients
            if let first = ingredients.first {
                ingredients[0] = Ingredient(paint: first.paint, parts: first.parts + 1)
            }
            model.setParts(Recipe(ingredients))
        }
        if demo == "submitted" {
            model.submit()
        }
        return model
    }
}

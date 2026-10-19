import SwiftUI

@main
struct ColorMatchApp: App {
    @StateObject private var model = ColorMatchApp.makeModel()
    @StateObject private var theory = ColorMatchApp.makeTheoryModel()

    var body: some Scene {
        WindowGroup {
            RootView(model: model, theory: theory, game: ColorMatchApp.demoGame, howTo: ColorMatchApp.demoHowTo)
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
        } else if let wrong = model.fitPuzzle.options.first(where: { $0.kind == .offTone }) {
            // A wrong pick being tried, so the screenshot shows the preview; "answered" confirms it.
            model.select(wrong)
            if demo == "theory-fit-answered" { model.confirmFit() }
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

/// Home, with the open game sliding in from the right over it. Kept in a view (not the App) so the slide animates.
private struct RootView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var theory: TheoryModel
    @State var game: Game?
    let howTo: Game?

    var body: some View {
        ZStack {
            HomeView(model: model, theory: theory, onPlay: { open($0) }, howTo: howTo)
            if let game {
                Group {
                    switch game {
                    case .mix: ContentView(model: model, onHome: { open(nil) })
                    case .theory: TheoryView(model: theory, onHome: { open(nil) })
                    }
                }
                .transition(.move(edge: .trailing))
                .zIndex(1)
            }
        }
        .animation(.smooth(duration: 0.35), value: game)
    }

    private func open(_ game: Game?) {
        withAnimation(.smooth(duration: 0.35)) { self.game = game }
    }
}

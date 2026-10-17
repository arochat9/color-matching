import SwiftUI

/// The two games the home page offers.
enum Game: String, Identifiable, CaseIterable {
    case mix, theory
    var id: String { rawValue }

    var title: String {
        switch self {
        case .mix: "Mix to Match"
        case .theory: "Color Theory"
        }
    }

    var tagline: String {
        switch self {
        case .mix: "Mix real paints to hit a goal color, then see the simplest recipe."
        case .theory: "Find the color that fits a set, and learn the harmony rules behind it."
        }
    }
}

/// Pick a game, or read how to play one.
struct HomeView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var theory: TheoryModel
    let onPlay: (Game) -> Void
    @State var howTo: Game? = nil
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Color Match")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(theme.ink)
                    Text("Train your eye for color, one round at a time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 6)
                GameCard(
                    game: .mix,
                    stat: Label("\(model.lifetimeScore)", systemImage: "star.fill"),
                    onPlay: { onPlay(.mix) },
                    onHowTo: { howTo = .mix }
                ) {
                    HStack(spacing: -10) {
                        ForEach(DynamicPalette.core) { paint in
                            PaintBlob(seed: paint.blobSeed)
                                .fill(paint.color.swiftUIColor)
                                .overlay(PaintBlob(seed: paint.blobSeed).stroke(.primary.opacity(0.18), lineWidth: 1))
                                .frame(width: 44, height: 44)
                        }
                    }
                }
                GameCard(
                    game: .theory,
                    stat: Label("\(theory.streak)", systemImage: "flame.fill"),
                    onPlay: { onPlay(.theory) },
                    onHowTo: { howTo = .theory }
                ) {
                    HarmonyWheel(dots: [0.0, 120, 240].map {
                        HarmonyWheel.Dot(color: Tone.vivid.color(hue: $0 + 20), style: .shown)
                    })
                    .frame(width: 96, height: 96)
                }
            }
            .padding()
        }
        .background(theme.canvas.ignoresSafeArea())
        .sheet(item: $howTo) { game in
            HowToPlayView(game: game) {
                howTo = nil
                onPlay(game)
            }
            .themed(theme)
            .presentationBackground(theme.canvas)
            .presentationDetents([.large])
        }
    }
}

private struct GameCard<Art: View>: View {
    let game: Game
    let stat: Label<Text, Image>
    let onPlay: () -> Void
    let onHowTo: () -> Void
    @ViewBuilder let art: () -> Art
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                art()
                Spacer(minLength: 8)
                stat
                    .font(.headline)
                    .foregroundStyle(theme.star)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(game.title).font(.title2.weight(.bold)).foregroundStyle(theme.ink)
                Text(game.tagline).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button(action: onHowTo) {
                    Label("How to play", systemImage: "questionmark.circle")
                }
                .buttonStyle(BouncyButtonStyle())
                Button(action: onPlay) {
                    Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(BouncyButtonStyle(prominent: true))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

/// Numbered steps for one game.
struct HowToPlayView: View {
    let game: Game
    let onPlay: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    private var steps: [(icon: String, title: String, text: String)] {
        switch game {
        case .mix:
            return [
                ("target", "Look at the goal", "Each round gives you a goal color, usually a named paint color like Burnt Sienna."),
                ("plus.circle.fill", "Add paint", "Tap + on a tube to add one part. Your mix updates as you go. Paint can't come back out, so add a little at a time."),
                ("paintbrush.pointed.fill", "Submit", "See how close you got, tips on what's off, and the fewest paints and ratio that make the goal."),
                ("star.fill", "Earn stars", "90% or better earns a star. The swatch button opens the color library, where you can practice any named color."),
            ]
        case .theory:
            return [
                ("square.grid.3x1.below.line.grid.1x2", "Best fit", "A set of colors is missing one. Pick which of the five options belongs with it."),
                ("eyedropper.halffull", "Find the hue", "Make the missing color yourself. The slider only covers one hue family, and the square sets brightness and saturation."),
                ("circle.dashed", "Hue and tone both count", "Colors in a set share a tone: pale, bright, dusty or deep. A right hue in the wrong tone still clashes."),
                ("graduationcap.fill", "Learn the rule", "Every answer names the harmony (complementary, analogous, split complementary, triadic or square) and shows it on the painter's color wheel."),
            ]
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text(game.tagline).font(.headline)
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(index + 1)")
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(theme.onAccent)
                                .frame(width: 32, height: 32)
                                .background(theme.accent, in: Circle())
                            VStack(alignment: .leading, spacing: 4) {
                                Label(step.title, systemImage: step.icon)
                                    .font(.headline)
                                    .foregroundStyle(theme.ink)
                                Text(step.text)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Button(action: onPlay) {
                        Label("Play", systemImage: "play.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BouncyButtonStyle(prominent: true))
                    .padding(.top, 6)
                }
                .padding()
            }
            .navigationTitle("How to play \(game.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

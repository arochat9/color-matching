import SwiftUI

struct ResultView: View {
    let result: RoundResult
    let onTryAgain: () -> Void
    let onNext: () -> Void

    /// Animated stand-in for the match percentage so it counts up when the sheet opens.
    @State private var shownPercent = 0.0
    @State private var revealed = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    splitSwatch.reveal(revealed, order: 1)
                    feedback.reveal(revealed, order: 2)
                    RecipeCard(
                        title: "Simplest recipe",
                        subtitle: "Fewest paints that reach the goal",
                        solution: result.simplest
                    )
                    .reveal(revealed, order: 3)
                    if result.closest.recipe != result.simplest.recipe,
                       result.closest.deltaE < result.simplest.deltaE - 0.3 {
                        RecipeCard(
                            title: "Closest recipe",
                            subtitle: "\(result.closest.recipe.paintCount) paints, a touch more accurate",
                            solution: result.closest
                        )
                        .reveal(revealed, order: 4)
                    }
                    yourRecipe.reveal(revealed, order: 5)
                    buttons.reveal(revealed, order: 6)
                }
                .padding()
            }
            if result.match.counts {
                ConfettiView(colors: confettiColors)
                    .ignoresSafeArea()
            }
        }
        .fontDesign(.rounded)
        .sensoryFeedback(.success, trigger: revealed) { _, now in now && result.match.counts }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shownPercent = result.match.matchPercent }
            revealed = true
        }
    }

    private var confettiColors: [Color] {
        [result.target.swiftUIColor, .orange, .yellow, .pink, .mint]
            + result.simplest.recipe.ingredients.map { $0.paint.color.swiftUIColor }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(shownPercent.rounded()))%")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(result.match.counts ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(Color.primary))
                    .contentTransition(.numericText(value: shownPercent))
                Text("match").font(.title3).foregroundStyle(.secondary)
                Spacer()
                if result.scoredPoint {
                    Label("+1", systemImage: "star.fill")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(.orange)
                        .symbolEffect(.bounce, value: revealed)
                        .scaleEffect(revealed ? 1 : 0.2)
                        .rotationEffect(.degrees(revealed ? 0 : -40))
                        .animation(.spring(duration: 0.6, bounce: 0.6).delay(0.9), value: revealed)
                }
            }
            if let name = result.targetName {
                Text(name).font(.title3.weight(.semibold))
            }
            Text(result.match.verdict).font(.headline)
            Text(String(format: "ΔE2000 %.1f · 90%% or better earns a point", result.match.deltaE))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var splitSwatch: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Rectangle().fill(result.target.swiftUIColor)
                SwatchLabel(text: "Goal \(result.target.hex)")
            }
            ZStack(alignment: .bottomTrailing) {
                Rectangle().fill(result.guess.swiftUIColor)
                SwatchLabel(text: "Yours \(result.guess.hex)")
            }
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(result.match.feedback, id: \.self) { note in
                Label(note, systemImage: "lightbulb")
                    .font(.subheadline)
            }
        }
    }

    private var yourRecipe: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your mix").font(.headline)
            RecipeList(recipe: result.guessRecipe)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Try again", action: onTryAgain)
                .buttonStyle(BouncyButtonStyle())
            Button(action: onNext) {
                Label("Next color", systemImage: "arrow.right").frame(maxWidth: .infinity)
            }
            .buttonStyle(BouncyButtonStyle(prominent: true))
        }
    }
}

private struct SwatchLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2.monospaced())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(8)
    }
}

struct RecipeCard: View {
    let title: String
    let subtitle: String
    let solution: Solution

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                PaintBlob(seed: 7)
                    .fill(solution.color.swiftUIColor.gradient)
                    .frame(width: 48, height: 48)
            }
            RecipeList(recipe: solution.recipe)
            Text(String(format: "Ratio %@ · ΔE %.1f from the goal", ratio, solution.deltaE))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var ratio: String {
        solution.recipe.ingredients.map { "\($0.parts)" }.joined(separator: ":")
    }
}

struct RecipeList: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(recipe.ingredients, id: \.paint.id) { ingredient in
                HStack(spacing: 10) {
                    PaintBlob(seed: ingredient.paint.blobSeed)
                        .fill(ingredient.paint.color.swiftUIColor.gradient)
                        .overlay(PaintBlob(seed: ingredient.paint.blobSeed).stroke(.black.opacity(0.08), lineWidth: 1))
                        .frame(width: 26, height: 26)
                    Text(ingredient.paint.name)
                    Spacer()
                    Text("\(ingredient.parts) \(ingredient.parts == 1 ? "part" : "parts")")
                        .monospacedDigit()
                    Text("\(Int((recipe.fraction(of: ingredient) * 100).rounded()))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                .font(.subheadline)
            }
        }
    }
}

private extension View {
    /// Slides content up into place, one section after another.
    func reveal(_ shown: Bool, order: Int) -> some View {
        self
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 24)
            .animation(.spring(duration: 0.5, bounce: 0.3).delay(0.15 + Double(order) * 0.08), value: shown)
    }
}

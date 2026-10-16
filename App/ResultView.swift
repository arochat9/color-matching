import SwiftUI

struct ResultView: View {
    let result: RoundResult
    let onTryAgain: () -> Void
    let onNext: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                splitSwatch
                feedback
                RecipeCard(
                    title: "Simplest recipe",
                    subtitle: "Fewest paints that reach the goal",
                    solution: result.simplest
                )
                if result.closest.recipe != result.simplest.recipe,
                   result.closest.deltaE < result.simplest.deltaE - 0.3 {
                    RecipeCard(
                        title: "Closest recipe",
                        subtitle: "\(result.closest.recipe.paintCount) paints, a touch more accurate",
                        solution: result.closest
                    )
                }
                yourRecipe
                buttons
            }
            .padding()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(result.match.matchPercent.rounded()))%")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(result.match.counts ? .green : .primary)
                Text("match").font(.title3).foregroundStyle(.secondary)
                Spacer()
                if result.scoredPoint {
                    Label("+1", systemImage: "star.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.orange)
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
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button("Try again", action: onTryAgain)
                .buttonStyle(.bordered)
            Button(action: onNext) {
                Text("Next color").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
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
                RoundedRectangle(cornerRadius: 8)
                    .fill(solution.color.swiftUIColor)
                    .frame(width: 44, height: 44)
            }
            RecipeList(recipe: solution.recipe)
            Text(String(format: "Ratio %@ · ΔE %.1f from the goal", ratio, solution.deltaE))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
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
                    Circle()
                        .fill(ingredient.paint.color.swiftUIColor)
                        .overlay(Circle().strokeBorder(.quaternary))
                        .frame(width: 22, height: 22)
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

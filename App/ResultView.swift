import SwiftUI

struct ResultView: View {
    let result: RoundResult
    let onTryAgain: () -> Void
    let onNext: () -> Void

    /// Animated stand-in for the match percentage so it counts up when the sheet opens.
    @State private var shownPercent = 0.0
    @State private var revealed = false
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    splitSwatch.reveal(revealed, order: 1)
                    feedback.reveal(revealed, order: 2)
                    RecipeTable(columns: recipeColumns).reveal(revealed, order: 3)
                    buttons.reveal(revealed, order: 4)
                }
                .padding()
            }
            if result.match.counts {
                ConfettiView(colors: confettiColors)
                    .ignoresSafeArea()
            }
        }
        .sensoryFeedback(.success, trigger: revealed) { _, now in now && result.match.counts }
        .onAppear {
            withAnimation(.easeOut(duration: 1.0)) { shownPercent = result.match.matchPercent }
            revealed = true
        }
    }

    /// The simplest recipe, the closest one when it's meaningfully better, then yours.
    private var recipeColumns: [RecipeTable.Column] {
        var columns = [RecipeTable.Column(title: "Simplest", recipe: result.simplest.recipe, color: result.simplest.color)]
        if result.closest.recipe != result.simplest.recipe,
           result.closest.deltaE < result.simplest.deltaE - 0.3 {
            columns.append(.init(title: "Closest", recipe: result.closest.recipe, color: result.closest.color))
        }
        columns.append(.init(title: "Yours", recipe: result.guessRecipe, color: result.guess))
        return columns
    }

    private var confettiColors: [Color] {
        [result.target.swiftUIColor, theme.star, theme.accent, theme.success, .white]
            + result.simplest.recipe.ingredients.map { $0.paint.color.swiftUIColor }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(Int(shownPercent.rounded()))%")
                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                    .foregroundStyle(result.match.counts ? AnyShapeStyle(theme.success.gradient) : AnyShapeStyle(theme.ink))
                    .contentTransition(.numericText(value: shownPercent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.match.verdict).font(.title3.weight(.bold))
                    if let name = result.targetName {
                        Text(name).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                if result.scoredPoint {
                    Label("+1", systemImage: "star.fill")
                        .font(.title2.weight(.heavy))
                        .foregroundStyle(theme.star)
                        .symbolEffect(.bounce, value: revealed)
                        .scaleEffect(revealed ? 1 : 0.2)
                        .rotationEffect(.degrees(revealed ? 0 : -40))
                        .animation(.spring(duration: 0.6, bounce: 0.6).delay(0.9), value: revealed)
                }
            }
            if result.isPractice {
                Label("Practice round, no star", systemImage: "graduationcap.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.info)
            }
            if result.closest.deltaE > 2 {
                Label("These paints can reach \(Int(result.bestPossiblePercent.rounded()))% at best", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(theme.warning)
            }
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
        .frame(height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(result.match.feedback, id: \.self) { note in
                Label(note, systemImage: "lightbulb.fill")
                    .font(.subheadline)
            }
        }
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

/// Recipes side by side: one row per paint, one column per recipe, parts with the share underneath.
struct RecipeTable: View {
    struct Column {
        let title: String
        let recipe: Recipe
        let color: SRGB
    }

    let columns: [Column]
    @Environment(\.theme) private var theme

    /// Every paint used by any column, in the order they first show up.
    private var paints: [Paint] {
        var seen = Set<String>()
        return columns.flatMap { $0.recipe.ingredients.map(\.paint) }.filter { seen.insert($0.id).inserted }
    }

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 10) {
            GridRow {
                Color.clear.gridCellUnsizedAxes([.horizontal, .vertical])
                ForEach(columns, id: \.title) { column in
                    VStack(spacing: 4) {
                        PaintBlob(seed: 7)
                            .fill(column.color.swiftUIColor.gradient)
                            .frame(width: 30, height: 30)
                        Text(column.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            ForEach(paints) { paint in
                GridRow {
                    HStack(spacing: 8) {
                        PaintBlob(seed: paint.blobSeed)
                            .fill(paint.color.swiftUIColor.gradient)
                            .overlay(PaintBlob(seed: paint.blobSeed).stroke(.black.opacity(0.08), lineWidth: 1))
                            .frame(width: 24, height: 24)
                        Text(paint.name).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                    }
                    ForEach(columns, id: \.title) { column in
                        cell(paint, in: column.recipe).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func cell(_ paint: Paint, in recipe: Recipe) -> some View {
        if let ingredient = recipe.ingredients.first(where: { $0.paint.id == paint.id }) {
            VStack(spacing: 0) {
                Text("\(ingredient.parts)").font(.headline.monospacedDigit())
                Text("\(Int((recipe.fraction(of: ingredient) * 100).rounded()))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("–").foregroundStyle(.tertiary)
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

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SwatchComparison(goal: model.challenge.target, goalName: model.goalName, mix: model.mixColor)
                    MixBar(recipe: model.currentRecipe)
                    paintList
                    actions
                }
                .padding()
            }
            .navigationTitle("Color Match")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ScoreBadge(score: model.lifetimeScore)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    settingsMenu
                }
            }
            .sheet(item: $model.result) { result in
                ResultView(
                    result: result,
                    onTryAgain: { model.result = nil },
                    onNext: { model.nextRound() }
                )
                .presentationDetents([.large])
            }
        }
    }

    private var paintList: some View {
        VStack(spacing: 0) {
            ForEach(model.palette.paints) { paint in
                PaintRow(
                    paint: paint,
                    parts: model.parts(of: paint),
                    onAdd: { model.add(paint) },
                    onRemove: { model.remove(paint) }
                )
                if paint.id != model.palette.paints.last?.id {
                    Divider().padding(.leading, 56)
                }
            }
        }
        .padding(.vertical, 4)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button("Clear", role: .destructive) { model.clearMix() }
                .buttonStyle(.bordered)
                .disabled(model.currentRecipe.isEmpty)
            Button {
                model.submit()
            } label: {
                Text("Submit").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.currentRecipe.isEmpty)
            Button("Skip") { model.nextRound() }
                .buttonStyle(.bordered)
        }
        .controlSize(.large)
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Palette", selection: $model.paletteID) {
                ForEach(Palette.all) { palette in
                    Text(palette.name).tag(palette.id)
                }
            }
            Picker("Goals", selection: $model.goalMode) {
                ForEach(GoalMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
        } label: {
            Image(systemName: "paintpalette")
        }
    }
}

struct ScoreBadge: View {
    let score: Int

    var body: some View {
        Label("\(score)", systemImage: "star.fill")
            .labelStyle(.titleAndIcon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.orange)
            .accessibilityLabel("Lifetime matches: \(score)")
    }
}

struct SwatchComparison: View {
    let goal: SRGB
    let goalName: (name: String, isExact: Bool)?
    let mix: SRGB?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let goalName {
                VStack(alignment: .leading, spacing: 0) {
                    Text(goalName.isExact ? "Mix this color" : "Closest color name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(goalName.name)
                        .font(.title2.weight(.semibold))
                }
            }
            HStack(spacing: 12) {
                Swatch(title: "Goal", color: goal, caption: goal.hex)
                Swatch(title: "Your mix", color: mix, caption: mix?.hex ?? "Add some paint")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Swatch: View {
    let title: String
    let color: SRGB?
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            RoundedRectangle(cornerRadius: 16)
                .fill(color?.swiftUIColor ?? Color.secondary.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary))
                .frame(height: 150)
            Text(caption)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// A strip showing each paint's share of the current mix.
struct MixBar: View {
    let recipe: Recipe

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(recipe.ingredients, id: \.paint.id) { ingredient in
                    Rectangle()
                        .fill(ingredient.paint.color.swiftUIColor)
                        .frame(width: geo.size.width * recipe.fraction(of: ingredient))
                }
            }
        }
        .frame(height: 10)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
}

struct PaintRow: View {
    let paint: Paint
    let parts: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(paint.color.swiftUIColor)
                .overlay(Circle().strokeBorder(.quaternary))
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(paint.name).font(.body.weight(.medium))
                Text(paint.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .disabled(parts == 0)
            Text("\(parts)")
                .font(.title3.monospacedDigit().weight(.semibold))
                .frame(minWidth: 28)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill").font(.title2)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: GameModel
    @State private var splashes: [Splash] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SwatchComparison(
                        goal: model.challenge.target,
                        goalName: model.goalName,
                        mix: model.mixColor,
                        splashes: splashes
                    )
                    MixBar(recipe: model.currentRecipe)
                    paintList
                    actions
                }
                .padding()
            }
            .background(backdrop)
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
                    onNext: { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.nextRound() } }
                )
                .presentationDetents([.large])
                .presentationCornerRadius(32)
            }
        }
        .task { await playDemoDropsIfRequested() }
    }

    /// A soft wash of the goal color behind everything.
    private var backdrop: some View {
        LinearGradient(
            colors: [model.challenge.target.swiftUIColor.opacity(0.28), Color(.systemBackground)],
            startPoint: .top,
            endPoint: .center
        )
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: model.challenge.target)
    }

    private func addDrop(of paint: Paint) {
        let splash = Splash(color: paint.color.swiftUIColor)
        splashes.append(splash)
        withAnimation(.easeInOut(duration: 0.45).delay(0.18)) {
            model.add(paint)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.2))
            splashes.removeAll { $0.id == splash.id }
        }
    }

    private var paintList: some View {
        VStack(spacing: 0) {
            ForEach(model.palette.paints) { paint in
                PaintRow(
                    paint: paint,
                    parts: model.parts(of: paint),
                    onAdd: { addDrop(of: paint) },
                    onRemove: { withAnimation(.easeInOut(duration: 0.3)) { model.remove(paint) } }
                )
                if paint.id != model.palette.paints.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .padding(.vertical, 4)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Clear") { withAnimation(.spring(duration: 0.4)) { model.clearMix() } }
                .buttonStyle(BouncyButtonStyle(tint: .red))
                .disabled(model.currentRecipe.isEmpty)
            Button {
                model.submit()
            } label: {
                Label("Submit", systemImage: "paintbrush.pointed.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(BouncyButtonStyle(tint: .accentColor, prominent: true))
            .disabled(model.currentRecipe.isEmpty)
            Button("Skip") { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.nextRound() } }
                .buttonStyle(BouncyButtonStyle(tint: .accentColor))
        }
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
            Image(systemName: "paintpalette.fill")
                .symbolRenderingMode(.multicolor)
                .font(.title3)
        }
    }

    /// `-demo drops` (used by CI): drip the goal's own recipe in, one drop at a time, then submit.
    private func playDemoDropsIfRequested() async {
        guard UserDefaults.standard.string(forKey: "demo") == "drops",
              let recipe = model.challenge.sourceRecipe else { return }
        try? await Task.sleep(for: .seconds(1))
        // Alternate between paints, the way you'd actually build up a mix.
        var remaining = recipe.ingredients.map(\.parts)
        while remaining.contains(where: { $0 > 0 }) {
            for (i, ingredient) in recipe.ingredients.enumerated() where remaining[i] > 0 {
                remaining[i] -= 1
                addDrop(of: ingredient.paint)
                try? await Task.sleep(for: .seconds(0.7))
            }
        }
        try? await Task.sleep(for: .seconds(0.8))
        model.submit()
    }
}

struct ScoreBadge: View {
    let score: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .symbolEffect(.bounce, value: score)
            Text("\(score)")
                .contentTransition(.numericText(value: Double(score)))
        }
        .font(.headline)
        .foregroundStyle(.orange)
        .animation(.spring, value: score)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lifetime matches: \(score)")
    }
}

struct SwatchComparison: View {
    let goal: SRGB
    let goalName: GoalName?
    let mix: SRGB?
    let splashes: [Splash]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let goalName {
                Text(goalName.headline)
                    .font(.title2.weight(.bold))
                    .id(goalName.headline)
                    .transition(.push(from: .trailing).combined(with: .opacity))
            }
            HStack(spacing: 12) {
                Swatch(title: "Goal", color: goal, caption: goal.hex)
                    .id(goal.hex)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                Swatch(title: "Your mix", color: mix, caption: mix?.hex ?? "Tap + to add paint", splashes: splashes)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Swatch: View {
    let title: String
    let color: SRGB?
    let caption: String
    var splashes: [Splash] = []

    /// Bumps each time a drop lands so the swatch can jiggle.
    private var dropCount: Int { splashes.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(color?.swiftUIColor ?? Color.secondary.opacity(0.12))
                if color == nil {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(.tertiary)
                        .symbolEffect(.pulse)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).strokeBorder(.white.opacity(0.35), lineWidth: 1))
            .shadow(color: (color?.swiftUIColor ?? .clear).opacity(0.45), radius: 14, y: 8)
            // Splashes sit outside the clip so droplets can fly past the edge.
            .overlay {
                ForEach(splashes) { splash in
                    SplashView(splash: splash)
                }
            }
            .zIndex(1)
            .frame(height: 160)
            .phaseAnimator([1.0, 1.06, 0.98, 1.0], trigger: dropCount) { content, scale in
                content.scaleEffect(scale)
            } animation: { _ in
                .spring(duration: 0.18, bounce: 0.4)
            }
            Text(caption)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}

/// A strip showing each paint's share of the current mix.
struct MixBar: View {
    let recipe: Recipe

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(recipe.ingredients, id: \.paint.id) { ingredient in
                    Capsule()
                        .fill(ingredient.paint.color.swiftUIColor)
                        .frame(width: max(0, geo.size.width * recipe.fraction(of: ingredient) - 2))
                }
            }
        }
        .frame(height: 12)
        .background(Color.secondary.opacity(0.12), in: Capsule())
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
            Button(action: onAdd) {
                PaintBlob(seed: paint.blobSeed)
                    .fill(paint.color.swiftUIColor.gradient)
                    .overlay(PaintBlob(seed: paint.blobSeed).stroke(.black.opacity(0.08), lineWidth: 1))
                    .frame(width: 44, height: 44)
                    .phaseAnimator([1.0, 1.25, 0.95, 1.0], trigger: parts) { content, scale in
                        content.scaleEffect(scale)
                    } animation: { _ in
                        .spring(duration: 0.16, bounce: 0.5)
                    }
            }
            .accessibilityLabel("Add a part of \(paint.name)")
            VStack(alignment: .leading, spacing: 2) {
                Text(paint.name).font(.body.weight(.semibold))
                Text(paint.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: onRemove) {
                Image(systemName: "minus.circle.fill").font(.title2)
            }
            .disabled(parts == 0)
            Text("\(parts)")
                .font(.title3.monospacedDigit().weight(.bold))
                .contentTransition(.numericText(value: Double(parts)))
                .frame(minWidth: 28)
            Button(action: onAdd) {
                Image(systemName: "plus.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(plusGlyph, plusCircle)
            }
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .sensoryFeedback(.impact(weight: .light), trigger: parts)
    }

    /// The + button wears the paint's color; very light paints get a gray button so it stays visible.
    private var isVeryLight: Bool { paint.color.lab.l > 85 }
    private var plusCircle: Color { isVeryLight ? Color.gray.opacity(0.5) : paint.color.swiftUIColor }
    private var plusGlyph: Color { .white }
}

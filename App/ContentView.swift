import SwiftUI

struct ContentView: View {
    @ObservedObject var model: GameModel
    @State private var splashes: [Splash] = []
    /// Only ever goes up, so the swatch jiggles once per drop (not again when a splash is cleaned up).
    @State private var dropCount = 0
    @State private var showLibrary = false
    @State private var showPalette = false
    @AppStorage("showWarnings") private var showWarnings = true
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    SwatchComparison(
                        goal: model.challenge.target,
                        goalName: model.goalName,
                        mix: model.mixColor,
                        splashes: splashes,
                        dropCount: dropCount
                    )
                    goalNotes
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
                        .fixedSize()
                        .padding(.horizontal, 6)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showLibrary = true
                    } label: {
                        Image(systemName: "swatchpalette.fill")
                            .symbolRenderingMode(.multicolor)
                            .font(.title3)
                    }
                    .accessibilityLabel("Color library")
                    settingsMenu
                }
            }
            .navigationDestination(isPresented: $showLibrary) {
                ColorLibraryView { color in
                    withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.practice(color) }
                }
                .background(theme.canvas.ignoresSafeArea())
            }
            .sheet(isPresented: $showPalette) {
                PaletteView(model: model)
                    .themed(theme)
                    .presentationBackground(theme.canvas)
                    .presentationDetents([.medium, .large])
            }
            .sheet(item: $model.result) { result in
                ResultView(
                    result: result,
                    onTryAgain: { model.result = nil },
                    onNext: { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.nextRound() } }
                )
                .themed(theme)
                .presentationBackground(theme.canvas)
                .presentationDetents([.large])
                .presentationCornerRadius(32)
            }
        }
        .task { await playDemoDropsIfRequested() }
    }

    /// Practice badge plus the "can't be mixed" and "point of no return" warnings.
    @ViewBuilder
    private var goalNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            if model.isPractice {
                Label("Practice · no star", systemImage: "graduationcap.fill")
                    .badgeStyle(theme.info)
            }
            if showWarnings, model.goalIsOutOfReach {
                WarningBanner(
                    icon: "exclamationmark.triangle.fill",
                    tint: theme.warning,
                    title: "Can't be mixed · best \(Int(Scoring.matchPercent(deltaE: model.goalReach).rounded()))%"
                ) {
                    EmptyView()
                }
            } else if showWarnings, model.isPastPointOfNoReturn {
                WarningBanner(
                    icon: "arrow.uturn.backward.circle.fill",
                    tint: theme.danger,
                    title: "Past the point of no return"
                ) {
                    Button("Start fresh") { withAnimation(.spring(duration: 0.4)) { model.clearMix() } }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.small)
                        .tint(theme.danger)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.spring(duration: 0.4), value: model.goalIsOutOfReach)
        .animation(.spring(duration: 0.4), value: model.isPastPointOfNoReturn)
    }

    private var backdrop: some View {
        theme.canvas.ignoresSafeArea()
    }

    private func addDrop(of paint: Paint) {
        let splash = Splash(color: paint.color.swiftUIColor)
        splashes.append(splash)
        dropCount += 1
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
            HStack {
                Text("Your paints").font(.headline)
                Spacer()
                Button {
                    showPalette = true
                } label: {
                    Label("Change", systemImage: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
            ForEach(model.palette.paints) { paint in
                PaintRow(
                    paint: paint,
                    parts: model.parts(of: paint),
                    isPickedForGoal: paint.id == model.extraPaint?.id,
                    onAdd: { addDrop(of: paint) },
                    onRemove: { withAnimation(.easeInOut(duration: 0.3)) { model.remove(paint) } }
                )
                if paint.id != model.palette.paints.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .padding(.vertical, 4)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 24))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("Clear") { withAnimation(.spring(duration: 0.4)) { model.clearMix() } }
                .buttonStyle(BouncyButtonStyle(tint: theme.danger))
                .disabled(model.currentRecipe.isEmpty)
            Button {
                model.submit()
            } label: {
                Label("Submit", systemImage: "paintbrush.pointed.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(BouncyButtonStyle(prominent: true))
            .disabled(model.currentRecipe.isEmpty || model.isSolving)
            Button(model.isPractice ? "Random" : "Skip") { withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.nextRound() } }
                .buttonStyle(BouncyButtonStyle())
        }
    }

    private var settingsMenu: some View {
        Menu {
            Picker("Goals", selection: $model.goalMode) {
                ForEach(GoalMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Button {
                showPalette = true
            } label: {
                Label("Change paints…", systemImage: "slider.horizontal.3")
            }
            Toggle("Mixing warnings", isOn: $showWarnings)
        } label: {
            Image(systemName: "paintpalette.fill")
                .symbolRenderingMode(.multicolor)
                .font(.title3)
        }
    }

    /// `-demo drops` (used by CI): drip the goal's own recipe in, one drop at a time, then submit.
    private func playDemoDropsIfRequested() async {
        if UserDefaults.standard.string(forKey: "demo") == "library" { showLibrary = true }
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
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .symbolEffect(.bounce, value: score)
            Text("\(score)")
                .contentTransition(.numericText(value: Double(score)))
        }
        .font(.headline)
        .foregroundStyle(theme.star)
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
    let dropCount: Int

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
                Swatch(title: "Your mix", color: mix, caption: mix?.hex ?? "Tap + to add paint", splashes: splashes, dropCount: dropCount)
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
    var dropCount = 0
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).foregroundStyle(theme.accent)
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
            // A glow drawn once as a blurred shape behind the swatch, cheaper than .shadow while it jiggles.
            .background {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill((color?.swiftUIColor ?? .clear).opacity(0.45))
                    .offset(y: 8)
                    .blur(radius: 14)
            }
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
    /// The seventh tube, picked to make this goal possible.
    var isPickedForGoal = false
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
            VStack(alignment: .leading, spacing: 1) {
                Text(paint.name).font(.body.weight(.semibold))
                if isPickedForGoal {
                    Label("Added for this color", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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

private extension View {
    func badgeStyle(_ tint: Color) -> some View {
        self
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

/// A tinted callout with an action, for warnings about the current mix.
/// A one-line warning with a small action on the right.
struct WarningBanner<Action: View>: View {
    let icon: String
    let tint: Color
    let title: String
    @ViewBuilder let action: () -> Action

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 4)
            action()
        }
        .padding(.leading, 12)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
        .transition(.scale(scale: 0.9).combined(with: .opacity))
    }
}

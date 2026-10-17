import SwiftUI

/// The color theory game: harmony quizzes, separate from mixing paint.
struct TheoryView: View {
    @ObservedObject var model: TheoryModel
    var onHome: (() -> Void)?
    @State private var showHowTo = false
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Picker("Quiz", selection: $model.mode) {
                        ForEach(TheoryModel.Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch model.mode {
                    case .fit: FitQuizView(model: model)
                    case .hue: HueQuizView(model: model)
                    }
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                if isAnswered {
                    Button {
                        withAnimation(.spring(duration: 0.5, bounce: 0.3)) {
                            model.mode == .fit ? model.nextFit() : model.nextHue()
                        }
                    } label: {
                        Label("Next set", systemImage: "arrow.right").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(BouncyButtonStyle(prominent: true))
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(theme.canvas)
                }
            }
            .background(theme.canvas.ignoresSafeArea())
            .navigationTitle("Color Theory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let onHome { HomeButton(action: onHome) }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showHowTo = true } label: {
                        Image(systemName: "questionmark.circle").font(.title3)
                    }
                    .accessibilityLabel("How to play")
                }
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill").symbolEffect(.bounce, value: model.streak)
                        Text("\(model.streak)").contentTransition(.numericText(value: Double(model.streak)))
                    }
                    .font(.headline)
                    .foregroundStyle(theme.star)
                    .animation(.spring, value: model.streak)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Best-fit streak: \(model.streak)")
                }
            }
            .sheet(isPresented: $showHowTo) {
                HowToPlayView(game: .theory) { showHowTo = false }
                    .themed(theme)
                    .presentationBackground(theme.canvas)
            }
        }
    }

    /// The next-set button stays pinned to the bottom once a set is answered.
    private var isAnswered: Bool {
        model.mode == .fit ? model.fitPick != nil : model.hueGrade != nil
    }
}

/// Back to the home page, at the top left of each game.
struct HomeButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "house.fill").font(.title3)
        }
        .accessibilityLabel("Home")
    }
}

/// "Which color fits the set?" with five options.
struct FitQuizView: View {
    @ObservedObject var model: TheoryModel
    @Environment(\.theme) private var theme

    private var puzzle: FitPuzzle { model.fitPuzzle }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Which color fits the set?").font(.title3.weight(.bold))
                if model.fitPick == nil {
                    Text("Look at where the hues sit on the color wheel, and at how bright or soft they are.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ColorSet(colors: puzzle.shown, slotTitle: model.fitPick == nil ? "?" : "Fits", slot: model.fitPick.map { _ in puzzle.answer.color })
                .frame(height: model.fitPick == nil ? 110 : 80)
            options
            if let pick = model.fitPick {
                explanation(for: pick)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sensoryFeedback(trigger: model.fitPick?.id) { _, new in
            guard new != nil else { return nil }
            return model.fitPick?.kind == .answer ? .success : .error
        }
    }

    private var options: some View {
        HStack(spacing: 10) {
            ForEach(puzzle.options) { option in
                Button {
                    withAnimation(.spring(duration: 0.45, bounce: 0.3)) { model.choose(option) }
                } label: {
                    OptionChip(option: option, pick: model.fitPick)
                }
                .buttonStyle(.plain)
                .disabled(model.fitPick != nil)
                .accessibilityLabel(option.color.name)
            }
        }
    }

    private func explanation(for pick: FitPuzzle.Option) -> some View {
        let correct = pick.kind == .answer
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(correct ? "That's it" : "Not quite", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(correct ? theme.success : theme.ink)
                    Text(puzzle.rule.title).font(.title2.weight(.bold))
                    Text("Tone: \(puzzle.tone.description)").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                HarmonyWheel(dots: puzzle.shown.map { HarmonyWheel.Dot(color: $0, style: .shown) } + [HarmonyWheel.Dot(color: puzzle.answer.color, style: .answer)])
                    .frame(width: 110, height: 110)
            }
            Text(puzzle.explanation(for: puzzle.answer)).font(.subheadline)
            if !correct {
                Divider()
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(pick.color.swiftUIColor).frame(width: 22, height: 22)
                    Text(puzzle.explanation(for: pick)).font(.subheadline)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct OptionChip: View {
    let option: FitPuzzle.Option
    let pick: FitPuzzle.Option?
    @Environment(\.theme) private var theme

    private var answered: Bool { pick != nil }
    private var isPick: Bool { pick?.id == option.id }
    private var isAnswer: Bool { option.kind == .answer }

    var body: some View {
        Circle()
            .fill(option.color.swiftUIColor)
            .overlay(Circle().strokeBorder(.primary.opacity(0.12), lineWidth: 1))
            .overlay {
                if answered && (isAnswer || isPick) {
                    Image(systemName: isAnswer ? "checkmark" : "xmark")
                        .font(.headline.weight(.heavy))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.4), radius: 2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(4)
            .overlay {
                if answered && isAnswer {
                    Circle().strokeBorder(theme.ink, lineWidth: 2.5)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .scaleEffect(answered && isAnswer ? 1.08 : 1)
            .opacity(answered && !isAnswer && !isPick ? 0.4 : 1)
    }
}

/// "Find the <family> that fits": pick the missing color with a picker limited to one hue family.
struct HueQuizView: View {
    @ObservedObject var model: TheoryModel
    @Environment(\.theme) private var theme

    private var puzzle: HuePuzzle { model.huePuzzle }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Find the \(puzzle.family.rawValue) that fits").font(.title3.weight(.bold))
                if model.hueGrade == nil {
                    Text("Pick a \(puzzle.family.rawValue) that belongs with these colors, in hue and in tone.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            ColorSet(colors: puzzle.shown, slotTitle: "Yours", slot: model.pick)
                .frame(height: model.hueGrade == nil ? 110 : 80)
            if let grade = model.hueGrade {
                result(grade)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                picker
            }
        }
        .sensoryFeedback(.success, trigger: model.hueGrade?.percent) { _, new in (new ?? 0) >= 85 }
    }

    private var picker: some View {
        VStack(spacing: 18) {
            ToneSquare(hue: model.pick.hue, saturation: $model.pick.saturation, brightness: $model.pick.brightness)
                .frame(height: 210)
            HueStrip(range: puzzle.family.range, hue: $model.pick.hue)
            Button {
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) { model.submitHue() }
            } label: {
                Label("Check", systemImage: "checkmark").frame(maxWidth: .infinity)
            }
            .buttonStyle(BouncyButtonStyle(prominent: true))
        }
    }

    private func result(_ grade: HueGrade) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(Int(grade.percent.rounded()))%")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(grade.percent >= 85 ? AnyShapeStyle(theme.success) : AnyShapeStyle(theme.ink))
                        .lineLimit(1)
                        .fixedSize()
                    Text("fit").font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 0) {
                    ZStack(alignment: .bottomLeading) {
                        Rectangle().fill(puzzle.target.swiftUIColor)
                        caption("Ideal")
                    }
                    ZStack(alignment: .bottomTrailing) {
                        Rectangle().fill(model.pick.swiftUIColor)
                        caption("Yours")
                    }
                }
                .frame(height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(grade.tips, id: \.self) { tip in
                    Label(tip, systemImage: "lightbulb").font(.subheadline)
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(puzzle.rule.title).font(.title2.weight(.bold))
                        Text("Tone: \(puzzle.tone.description)").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    HarmonyWheel(dots: puzzle.shown.map { HarmonyWheel.Dot(color: $0, style: .shown) } + [
                        HarmonyWheel.Dot(color: puzzle.target, style: .answer),
                        HarmonyWheel.Dot(color: model.pick, style: .pick),
                    ])
                    .frame(width: 110, height: 110)
                }
                Text(puzzle.explanation).font(.subheadline)
                if let other = grade.alsoFits {
                    Label("Your pick makes a \(other.title.lowercased()) set instead, which also works.", systemImage: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(theme.info)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.3), in: Capsule())
            .foregroundStyle(.white)
            .padding(8)
    }
}

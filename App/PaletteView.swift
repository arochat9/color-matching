import SwiftUI

/// Pick which tubes are on your palette, and whether to get one extra tube per goal.
struct PaletteView: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

    /// Big palettes make the recipe search slow, and painters rarely set out more than this.
    static let maxTubes = 10

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(isOn: $model.autoExtra) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Add a tube when needed")
                            Text("When your paints can't get close to a goal, the tube that helps most joins them for that round.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                section("Basics", paints: DynamicPalette.core)
                section("Specialty tubes", paints: DynamicPalette.extras)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle("Your paints")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { model.tubeIDs = Set(DynamicPalette.core.map(\.id)) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func section(_ title: String, paints: [Paint]) -> some View {
        Section {
            ForEach(paints) { paint in
                PaletteTubeRow(
                    paint: paint,
                    isOn: model.tubeIDs.contains(paint.id),
                    // Keep at least two tubes, and no more than `maxTubes`.
                    canToggle: model.tubeIDs.contains(paint.id)
                        ? model.tubeIDs.count > 2
                        : model.tubeIDs.count < PaletteView.maxTubes
                ) {
                    model.tubeIDs.formSymmetricDifference([paint.id])
                }
            }
        } header: {
            Text(title)
        } footer: {
            if paints == DynamicPalette.extras {
                Text("\(model.tubeIDs.count) of up to \(PaletteView.maxTubes) tubes.")
            }
        }
        .listRowBackground(theme.surface)
    }
}

private struct PaletteTubeRow: View {
    let paint: Paint
    let isOn: Bool
    let canToggle: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                PaintBlob(seed: paint.blobSeed)
                    .fill(paint.color.swiftUIColor)
                    .overlay(PaintBlob(seed: paint.blobSeed).stroke(.primary.opacity(0.18), lineWidth: 1))
                    .frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(paint.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                    Text(paint.note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canToggle)
        .opacity(canToggle || isOn ? 1 : 0.5)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

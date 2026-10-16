import SwiftUI

/// Every named color, grouped by hue. Tap one to practice mixing it.
struct ColorLibraryView: View {
    let onPick: (NamedColor) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var sections: [(family: String, colors: [NamedColor])] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return GameModel.librarySections }
        return GameModel.librarySections.compactMap { section in
            let matches = section.colors.filter {
                $0.name.localizedCaseInsensitiveContains(query) || $0.color.hex.localizedCaseInsensitiveContains(query)
            }
            return matches.isEmpty ? nil : (section.family, matches)
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 104), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                ForEach(sections, id: \.family) { section in
                    Section {
                        ForEach(section.colors, id: \.name) { color in
                            Button {
                                onPick(color)
                                dismiss()
                            } label: {
                                ColorTile(color: color)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("\(section.family.capitalized) · \(section.colors.count)")
                            .font(.headline)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.bar)
                    }
                }
            }
            .padding(.horizontal)
        }
        .navigationTitle("Color library")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search names or hex")
        .safeAreaInset(edge: .bottom) {
            Text("Tap a color to practice mixing it. Practice rounds don't earn stars.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }
}

private struct ColorTile: View {
    let color: NamedColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.color.swiftUIColor)
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.primary.opacity(0.08)))
                .frame(height: 72)
            Text(color.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(color.color.hex)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

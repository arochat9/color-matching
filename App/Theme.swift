import SwiftUI
import UIKit

/// The app's own colors (not the paints). Picked with `-theme <id>` while we try out options.
struct Theme {
    let id: String
    let name: String
    /// Main buttons and controls.
    let accent: Color
    /// Stars and the score.
    let star: Color
    /// A match that earns a point.
    let success: Color
    /// Practice badges.
    let info: Color
    /// Out-of-reach warnings.
    let warning: Color
    /// The Clear button.
    let danger: Color
    /// The page behind everything.
    let canvas: Color
    /// Cards sitting on the canvas.
    let surface: Color
    /// Big headline text.
    let ink: Color
    let fontDesign: Font.Design
    /// Forces light or dark; nil follows the system.
    let colorScheme: ColorScheme?

    /// What the app looked like before theming, kept for comparison.
    static let system = Theme(
        id: "system", name: "System",
        accent: .accentColor, star: .orange, success: .green, info: .blue, warning: .orange, danger: .red,
        canvas: Color(.systemBackground), surface: Color(.secondarySystemBackground), ink: .primary,
        fontDesign: .rounded, colorScheme: nil
    )

    /// Warm cream paper with earth pigments: burnt sienna, yellow ochre, sap green.
    static let studio = Theme(
        id: "studio", name: "Studio",
        accent: Color(light: 0xB5502D, dark: 0xE07A4F),
        star: Color(light: 0xC98A1B, dark: 0xE8B04A),
        success: Color(light: 0x5B7A34, dark: 0x8FB25E),
        info: Color(light: 0x34557A, dark: 0x86A6CC),
        warning: Color(light: 0xC98A1B, dark: 0xE8B04A),
        danger: Color(light: 0x9E2B37, dark: 0xD9606B),
        canvas: Color(light: 0xF4EDE1, dark: 0x1F1B17),
        surface: Color(light: 0xFFFAF2, dark: 0x2B2621),
        ink: Color(light: 0x2D2520, dark: 0xF1E8DC),
        fontDesign: .serif, colorScheme: nil
    )

    /// Sketchbook: off-white page, charcoal controls, one cadmium-orange highlight.
    static let sketchbook = Theme(
        id: "sketchbook", name: "Sketchbook",
        accent: Color(light: 0x2E2B28, dark: 0xECE8E1),
        star: Color(light: 0xE0661F, dark: 0xF08A45),
        success: Color(light: 0xE0661F, dark: 0xF08A45),
        info: Color(light: 0x6B655E, dark: 0xA9A29A),
        warning: Color(light: 0xE0661F, dark: 0xF08A45),
        danger: Color(light: 0x6B655E, dark: 0xA9A29A),
        canvas: Color(light: 0xF7F5F0, dark: 0x181716),
        surface: Color(light: 0xFFFFFF, dark: 0x252321),
        ink: Color(light: 0x1F1D1B, dark: 0xF2EFEA),
        fontDesign: .default, colorScheme: nil
    )

    /// Sage and viridian, like a plein-air landscape palette.
    static let garden = Theme(
        id: "garden", name: "Garden",
        accent: Color(light: 0x2F6B5A, dark: 0x6FB59E),
        star: Color(light: 0xD39B2A, dark: 0xE9BC5C),
        success: Color(light: 0x2F6B5A, dark: 0x6FB59E),
        info: Color(light: 0x5A6E8C, dark: 0x9DB0CC),
        warning: Color(light: 0xC4702E, dark: 0xE39A5E),
        danger: Color(light: 0xA8443C, dark: 0xD9776E),
        canvas: Color(light: 0xE8ECE3, dark: 0x171C19),
        surface: Color(light: 0xF8FAF5, dark: 0x222925),
        ink: Color(light: 0x1E2A24, dark: 0xE6EEE8),
        fontDesign: .rounded, colorScheme: nil
    )

    /// Night studio: warm charcoal walls with lamp-lit gold.
    static let night = Theme(
        id: "night", name: "Night Studio",
        accent: Color(hex: 0xE6A23C),
        star: Color(hex: 0xF2C14E),
        success: Color(hex: 0x9CC27A),
        info: Color(hex: 0x8FA8C8),
        warning: Color(hex: 0xE6A23C),
        danger: Color(hex: 0xD9665B),
        canvas: Color(hex: 0x1C1A18),
        surface: Color(hex: 0x2A2724),
        ink: Color(hex: 0xF3ECE2),
        fontDesign: .serif, colorScheme: .dark
    )

    static let all = [system, studio, sketchbook, garden, night]

    static var launchChoice: Theme {
        let id = UserDefaults.standard.string(forKey: "theme")
        return all.first { $0.id == id } ?? system
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.system
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies a theme's colors and type. Sheets get it again since they don't always inherit it.
    func themed(_ theme: Theme) -> some View {
        self
            .environment(\.theme, theme)
            .fontDesign(theme.fontDesign)
            .tint(theme.accent)
            .preferredColorScheme(theme.colorScheme)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A color that switches with light and dark mode.
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
    }
}

import SwiftUI
import UIKit

/// The app's own colors (not the paints): a sketchbook look with an off-white page,
/// charcoal controls and one cadmium-orange highlight, so the paints carry the color.
struct Theme {
    /// Main buttons and controls.
    let accent: Color
    /// Text and icons on a filled accent button.
    let onAccent: Color
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

    static let sketchbook = Theme(
        accent: Color(light: 0x2E2B28, dark: 0xECE8E1),
        onAccent: Color(light: 0xFFFFFF, dark: 0x1F1D1B),
        star: Color(light: 0xE0661F, dark: 0xF08A45),
        success: Color(light: 0xE0661F, dark: 0xF08A45),
        info: Color(light: 0x6B655E, dark: 0xA9A29A),
        warning: Color(light: 0xE0661F, dark: 0xF08A45),
        danger: Color(light: 0x6B655E, dark: 0xA9A29A),
        canvas: Color(light: 0xF7F5F0, dark: 0x181716),
        surface: Color(light: 0xFFFFFF, dark: 0x252321),
        ink: Color(light: 0x1F1D1B, dark: 0xF2EFEA)
    )
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.sketchbook
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    /// Applies the theme's colors. Sheets get it again since they don't always inherit it.
    func themed(_ theme: Theme) -> some View {
        self
            .environment(\.theme, theme)
            .tint(theme.accent)
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

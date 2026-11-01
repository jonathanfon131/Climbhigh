import ClimbHighCore
import SwiftUI
import UIKit

/// All colors in one place. Every text/background pair was checked against
/// WCAG contrast (≥ 4.5:1 for body text) in both light and dark mode.
enum Palette {
    // Brand accents (used as fills with `ink` text on top — 13:1+ contrast)
    static let volt = SharedPalette.volt
    static let coral = SharedPalette.coral
    static let sky = SharedPalette.sky
    static let lilac = Color(red: 0.725, green: 0.643, blue: 1.0) // #B9A4FF
    static let ink = SharedPalette.ink

    // Surfaces
    static let background = Color(light: 0xF3F3EE, dark: 0x0B0B0D)
    static let surface = Color(light: 0xFFFFFF, dark: 0x17171A)
    static let surfaceRaised = Color(light: 0xE9E9E2, dark: 0x232327)
    static let hairline = Color(light: 0xDADAD2, dark: 0x2E2E33)

    // Text
    static let textPrimary = Color(light: 0x0B0B0D, dark: 0xF5F5F2)
    static let textSecondary = Color(light: 0x55555C, dark: 0xA3A3AD)

    /// Accent for text and icons on normal backgrounds (lime is too light to read on white).
    static let accent = Color(light: 0x4D7A00, dark: 0xD4FF3B)
}

extension Color {
    /// A color that switches with Light/Dark mode. Values are 0xRRGGBB.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Spacing and shape tokens so every screen lines up.
enum Metrics {
    static let screenPadding: CGFloat = 20
    static let cardPadding: CGFloat = 20
    static let cardRadius: CGFloat = 28
    static let tileRadius: CGFloat = 24
    static let stackSpacing: CGFloat = 16
    /// Minimum tap target (Apple HIG + WCAG guidance).
    static let minTapTarget: CGFloat = 44
}

// MARK: - Intensity styling

extension SetIntensity {
    var color: Color {
        switch self {
        case .light: Palette.sky
        case .heavy: Palette.volt
        case .failure: Palette.coral
        }
    }

    var symbol: String {
        switch self {
        case .light: "leaf.fill"
        case .heavy: "scalemass.fill"
        case .failure: "flame.fill"
        }
    }
}

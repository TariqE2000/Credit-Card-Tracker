import SwiftUI
import UIKit

// MARK: - Color helpers

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

extension Color {
    /// A fixed color from a 0xRRGGBB value.
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }

    /// A color that switches between a light-mode and a dark-mode value.
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - Theme

/// Colors and sizes taken from the onboarding design (light and dark).
enum Theme {
    // Surfaces
    static let background = Color(light: 0xF6F6F9, dark: 0x1C1C1E)
    static let surface = Color(light: 0xFFFFFF, dark: 0x26262B)
    static let field = Color(light: 0xEDEDF2, dark: 0x2C2C32)
    static let border = Color(light: 0xE4E4EB, dark: 0x34343B)

    // Text
    static let textPrimary = Color(light: 0x16161A, dark: 0xFFFFFF)
    static let textSecondary = Color(light: 0x6B6B78, dark: 0x9C9CA6)

    // Accent (indigo / purple)
    static let accent = Color(hex: 0x5B4CF0)
    /// Accent for text and icons; a lighter purple in dark mode so it stays readable.
    static let accentText = Color(light: 0x5B4CF0, dark: 0x9A8FFF)
    /// Fill behind a selected row.
    static let accentTint = Color(light: 0xEAE8FC, dark: 0x27244D)

    // Status
    static let danger = Color(light: 0xD9363E, dark: 0xFF7A7A)

    // Badge used for a card that has no details yet
    static let mutedBadge = Color(light: 0xDADAE1, dark: 0x3A3A41)

    enum Metrics {
        static let screenPadding: CGFloat = 24
        static let cornerRadius: CGFloat = 14
        static let controlHeight: CGFloat = 52
    }
}

// MARK: - Fonts

/// The design uses Inter. Inter is not part of iOS, so until the font files are added to the
/// app bundle (and listed under "Fonts provided by application") this falls back to the
/// system font, which looks very close.
enum AppFont {
    private static let isInterInstalled = UIFont(name: "Inter-Regular", size: 12) != nil

    static func make(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard isInterInstalled else {
            return .system(size: size, weight: weight)
        }
        return .custom(interName(for: weight), size: size)
    }

    private static func interName(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return "Inter-Bold"
        case .semibold:
            return "Inter-SemiBold"
        case .medium:
            return "Inter-Medium"
        default:
            return "Inter-Regular"
        }
    }
}

extension Font {
    /// `Font.app(16, .semibold)`
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        AppFont.make(size, weight)
    }
}

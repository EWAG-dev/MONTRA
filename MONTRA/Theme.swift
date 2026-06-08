import SwiftUI
import UIKit

extension Color {
    private struct MontraPalette {
        let background: UIColor
        let surface: UIColor
        let textPrimary: UIColor
        let textSecondary: UIColor
        let divider: UIColor
        let cardBorder: UIColor
        let tabBarBackground: UIColor
        let accentFrost: UIColor
        let accentBorder: UIColor
    }

    private static let darkPalette = MontraPalette(
        background: UIColor(hex: "#000000"),
        surface: UIColor.white.withAlphaComponent(0.02),
        textPrimary: .white,
        textSecondary: UIColor(hex: "#8E8E93"),
        divider: UIColor.white.withAlphaComponent(0.10),
        cardBorder: UIColor(hex: "#F07840").withAlphaComponent(0.30),
        tabBarBackground: UIColor(hex: "#0C0C0C"),
        accentFrost: UIColor(hex: "#FF5A00").withAlphaComponent(0.14),
        accentBorder: UIColor(hex: "#FF5A00").withAlphaComponent(0.42)
    )

    private static let lightPalette = MontraPalette(
        background: UIColor(hex: "#FFFFFF"),
        surface: UIColor(hex: "#FFFFFF"),
        textPrimary: UIColor(hex: "#111318"),
        textSecondary: UIColor(hex: "#606672"),
        divider: UIColor(hex: "#DDE1E7"),
        cardBorder: UIColor(hex: "#DDE1E7"),
        tabBarBackground: UIColor(hex: "#FDFDFE"),
        accentFrost: UIColor(hex: "#FF5A00").withAlphaComponent(0.12),
        accentBorder: UIColor(hex: "#FF5A00").withAlphaComponent(0.34)
    )

    private static func token(_ keyPath: KeyPath<MontraPalette, UIColor>) -> Color {
        Color(
            UIColor { trait in
                let palette = trait.userInterfaceStyle == .dark ? darkPalette : lightPalette
                return palette[keyPath: keyPath]
            }
        )
    }

    private static func modeColor(dark: UIColor, light: UIColor) -> Color {
        Color(
            UIColor { trait in
                return trait.userInterfaceStyle == .dark ? dark : light
            }
        )
    }

    static let montraBackground = token(\.background)
    static let montraSurface = token(\.surface)
    static let montraTextPrimary = token(\.textPrimary)
    static let montraTextSecondary = token(\.textSecondary)
    static let montraDivider = token(\.divider)
    static let montraCardBorder = token(\.cardBorder)
    static let montraTabBarBackground = token(\.tabBarBackground)
    static let montraAccentFrost = token(\.accentFrost)
    static let montraAccentBorder = token(\.accentBorder)

    static let montraOrange = modeColor(
        dark: UIColor(hex: "#FF5A00"),
        light: UIColor(hex: "#FF6820")
    )
    static let montraOrangeLight = modeColor(
        dark: UIColor(hex: "#FF8A3D"),
        light: UIColor(hex: "#FF9A52")
    )
    
    static let montraFrostedSurface = modeColor(
        dark: UIColor.white.withAlphaComponent(0.05),
        light: UIColor.white.withAlphaComponent(0.78)
    )
    static let montraFrostedStroke = modeColor(
        dark: UIColor.white.withAlphaComponent(0.14),
        light: UIColor(hex: "#DDE1E7").withAlphaComponent(0.95)
    )
    static let montraFrostedOrangeFill = modeColor(
        dark: UIColor(hex: "#FF6A00").withAlphaComponent(0.18),
        light: UIColor(hex: "#FF6A00").withAlphaComponent(0.10)
    )
    static let montraFrostedOrangeStroke = modeColor(
        dark: UIColor(hex: "#FF6A00").withAlphaComponent(0.45),
        light: UIColor(hex: "#FF6A00").withAlphaComponent(0.42)
    )
    static let montraPrimaryButtonFill = modeColor(
        dark: UIColor(hex: "#FF5A00"),
        light: UIColor(hex: "#FF6A00").withAlphaComponent(0.14)
    )
    static let montraPrimaryButtonFillPressed = modeColor(
        dark: UIColor(hex: "#FF8A3D"),
        light: UIColor(hex: "#FF6A00").withAlphaComponent(0.22)
    )
    static let montraPrimaryButtonStroke = modeColor(
        dark: UIColor.clear,
        light: UIColor(hex: "#FF6A00").withAlphaComponent(0.40)
    )
    static let montraPrimaryButtonText = modeColor(
        dark: UIColor.white,
        light: UIColor(hex: "#8A2F00")
    )

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).uppercased()

        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

extension View {
    func montraCard(radius: CGFloat) -> some View {
        self
            .background(Color.montraSurface)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.montraCardBorder, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }

    func montraFrostedCard(radius: CGFloat) -> some View {
        self
            .background(Color.montraFrostedSurface)
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.montraFrostedStroke, lineWidth: 0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct MontraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.montraPrimaryButtonText)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                configuration.isPressed
                    ? Color.montraPrimaryButtonFillPressed
                    : Color.montraPrimaryButtonFill
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.montraPrimaryButtonStroke, lineWidth: 0.9)
            )
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

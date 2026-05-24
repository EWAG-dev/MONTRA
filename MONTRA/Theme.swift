import SwiftUI

extension Color {
    static let montraBackground    = Color(hex: "#000000")
    static let montraSurface       = Color.white.opacity(0.02)
    static let montraOrange        = Color(hex: "#E8621A")
    static let montraOrangeLight   = Color(hex: "#F07840")
    static let montraTextPrimary   = Color.white
    static let montraTextSecondary = Color(hex: "#8E8E93")
    static let montraDivider       = Color.white.opacity(0.10)
    static let montraCardBorder    = Color.montraOrangeLight.opacity(0.30)

    init(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
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
}

struct MontraButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                configuration.isPressed
                    ? Color.montraOrangeLight
                    : Color.montraOrange
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

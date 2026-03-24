import SwiftUI
import Foundation

extension Color {
    // Light mode colors (primary)
    static let vendaForest = Color(light: Color(hex: "#1A5C3A"), dark: Color(hex: "#2D7A50"))
    static let vendaForestMid = Color(light: Color(hex: "#2D7A50"), dark: Color(hex: "#1A5C3A"))
    static let vendaForestLt = Color(light: Color(hex: "#E8F4ED"), dark: Color(hex: "#0F3D25"))
    static let vendaForestDk = Color(light: Color(hex: "#0F3D25"), dark: Color(hex: "#E8F4ED"))

    static let vendaOchre = Color(light: Color(hex: "#C17D2A"), dark: Color(hex: "#E8A855"))
    static let vendaOchreLt = Color(light: Color(hex: "#FBF0DC"), dark: Color(hex: "#5A3D1F"))
    static let vendaOchreDk = Color(light: Color(hex: "#7A4D15"), dark: Color(hex: "#F5C89A"))

    static let vendaEmber = Color(light: Color(hex: "#B84040"), dark: Color(hex: "#E85858"))
    static let vendaEmberLt = Color(light: Color(hex: "#FAEAEA"), dark: Color(hex: "#5A2A2A"))
    static let vendaEmberDk = Color(light: Color(hex: "#7A2020"), dark: Color(hex: "#FF7070"))

    static let vendaSand = Color(light: Color(hex: "#F7F3EC"), dark: Color(hex: "#1A1714"))
    static let vendaParchment = Color(light: Color(hex: "#EDE7DC"), dark: Color(hex: "#2A231A"))
    static let vendaInk = Color(light: Color(hex: "#1C1A17"), dark: Color(hex: "#F0EBDF"))
    static let vendaInkMid = Color(light: Color(hex: "#5A5650"), dark: Color(hex: "#B8B0A0"))
    static let vendaInkLt = Color(light: Color(hex: "#9C978F"), dark: Color(hex: "#6B6560"))
    static let vendaLine = Color(light: Color(hex: "#DDD8CF"), dark: Color(hex: "#3A3530"))
    static let vendaWhite = Color(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#1F1A14"))
}

private extension Color {
    init(light: Color, dark: Color) {
        self.init(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }

    init(hex: String) {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}


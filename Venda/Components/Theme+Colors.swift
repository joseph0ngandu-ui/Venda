import SwiftUI

public extension ShapeStyle where Self == Color {
    static var vendaSand: Color { Color("VendaSand", bundle: .main) ?? Color(.systemGray6) }
    static var vendaForest: Color { Color("VendaForest", bundle: .main) ?? Color(.systemGreen) }
    static var vendaForestLt: Color { Color("VendaForestLt", bundle: .main) ?? Color(.systemGreen).opacity(0.15) }
    static var vendaInk: Color { Color("VendaInk", bundle: .main) ?? Color(.label) }
    static var vendaWhite: Color { Color("VendaWhite", bundle: .main) ?? Color(.systemBackground) }
}

public extension Color {
    static var vendaSand: Color { Color("VendaSand", bundle: .main) ?? Color(.systemGray6) }
    static var vendaForest: Color { Color("VendaForest", bundle: .main) ?? Color(.systemGreen) }
    static var vendaForestLt: Color { Color("VendaForestLt", bundle: .main) ?? Color(.systemGreen).opacity(0.15) }
    static var vendaInk: Color { Color("VendaInk", bundle: .main) ?? Color(.label) }
    static var vendaWhite: Color { Color("VendaWhite", bundle: .main) ?? Color(.systemBackground) }
}

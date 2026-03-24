import SwiftUI

struct VendaCard<Content: View>: View {
    let content: Content
    var accentColor: Color? = nil
    var backgroundColor: Color = .vendaWhite
    var borderColor: Color = .vendaLine
    var elevation: CardElevation = .default_
    
    enum CardElevation {
        case none
        case subtle
        case default_
        case elevated
    }

    init(
        accentColor: Color? = nil,
        backgroundColor: Color = .vendaWhite,
        borderColor: Color = .vendaLine,
        elevation: CardElevation = .default_,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.elevation = elevation
        self.content = content()
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if let accentColor = accentColor {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 3)
            }

            content
                .padding(DesignSystem.Spacing.md)
        }
        .background(backgroundColor)
        .cornerRadius(DesignSystem.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: shadowX,
            y: shadowY
        )
    }
    
    private var shadowColor: Color {
        switch elevation {
        case .none: return .clear
        case .subtle: return .black.opacity(0.05)
        case .default_: return .black.opacity(0.08)
        case .elevated: return .black.opacity(0.12)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch elevation {
        case .none: return 0
        case .subtle: return 4
        case .default_: return 8
        case .elevated: return 12
        }
    }
    
    private var shadowX: CGFloat {
        switch elevation {
        case .none: return 0
        case .subtle: return 0
        case .default_: return 0
        case .elevated: return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch elevation {
        case .none: return 0
        case .subtle: return 2
        case .default_: return 4
        case .elevated: return 6
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        VendaCard {
            Text("Default card")
        }
        VendaCard(accentColor: .vendaForest) {
            Text("Card with accent")
        }
    }
    .padding()
    .background(Color.vendaSand)
}

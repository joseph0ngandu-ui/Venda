import SwiftUI

struct VendaButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isEnabled: Bool = true

    enum ButtonStyle {
        case primary
        case danger
        case ghost
        case flat
    }

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .tint(foregroundColor)
            } else {
                Text(title)
                    .font(.system(size: 15, weight: .medium, design: .default))
            }
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: return .vendaWhite
        case .danger: return .vendaWhite
        case .ghost: return .vendaForest
        case .flat: return .vendaInk
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .vendaForest
        case .danger: return .vendaEmber
        case .ghost: return .clear
        case .flat: return .vendaParchment
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost: return .vendaForest
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        style == .ghost ? 1.5 : 0
    }
}

#Preview {
    VStack(spacing: 12) {
        VendaButton(title: "Primary", action: {})
        VendaButton(title: "Danger", action: {}, style: .danger)
        VendaButton(title: "Ghost", action: {}, style: .ghost)
        VendaButton(title: "Flat", action: {}, style: .flat)
    }
    .padding()
}

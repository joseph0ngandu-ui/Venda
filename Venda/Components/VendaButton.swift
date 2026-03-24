import SwiftUI

struct VendaButton: View {
    let title: String
    let action: () -> Void
    var style: ButtonStyle = .primary
    var size: ButtonSize = .large
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var isFullWidth: Bool = true
    var icon: String? = nil
    var accessibilityLabel: String? = nil

    enum ButtonStyle {
        case primary
        case danger
        case ghost
        case flat
        case secondary
    }
    
    enum ButtonSize {
        case small
        case medium
        case large
    }
    
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: iconSize, weight: .semibold))
                }
                
                if isLoading {
                    ProgressView()
                        .tint(foregroundColor)
                } else {
                    Text(title)
                        .font(DesignSystem.Typography.button)
                }
            }
        }
        .frame(height: buttonHeight)
        .frame(maxWidth: isFullWidth ? .infinity : nil)
        .foregroundColor(foregroundColor)
        .background(backgroundColor)
        .cornerRadius(DesignSystem.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
        .opacity(isEnabled && !isLoading ? 1 : DesignSystem.Opacity.disabled)
        .scaleEffect(isPressed && isEnabled ? 0.96 : 1.0)
        .disabled(!isEnabled || isLoading)
        .contentShape(Rectangle())
        .onLongPressGesture(
            minimumDuration: .infinity,
            pressing: { pressing in
                if isEnabled && !isLoading {
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                }
            },
            perform: {}
        )
        .accessibilityLabel(accessibilityLabel ?? title)
        .accessibilityHint(isLoading ? "Loading" : isEnabled ? "" : "Disabled")
    }

    private var foregroundColor: Color {
        switch style {
        case .primary, .danger: return .vendaWhite
        case .ghost, .secondary: return .vendaForest
        case .flat: return .vendaInk
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: return .vendaForest
        case .danger: return .vendaEmber
        case .secondary: return .vendaForestLt
        case .ghost: return .clear
        case .flat: return .vendaParchment
        }
    }

    private var borderColor: Color {
        switch style {
        case .ghost, .secondary: return .vendaForest
        default: return .clear
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .ghost, .secondary: return 1.5
        default: return 0
        }
    }
    
    private var buttonHeight: CGFloat {
        switch size {
        case .small: return DesignSystem.ComponentSize.buttonHeightSmall
        case .medium: return 44
        case .large: return DesignSystem.ComponentSize.buttonHeightLarge
        }
    }
    
    private var iconSize: CGFloat {
        switch size {
        case .small: return 14
        case .medium: return 16
        case .large: return 18
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary, .danger: return Color.black.opacity(0.1)
        default: return .clear
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .primary, .danger: return 8
        default: return 0
        }
    }
    
    private var shadowY: CGFloat {
        switch style {
        case .primary, .danger: return 4
        default: return 0
        }
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

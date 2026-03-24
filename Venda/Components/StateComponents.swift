import SwiftUI

/// Loading skeleton for placeholders during content loading
struct SkeletonCard: View {
    var body: some View {
        VendaCard {
            VStack(spacing: DesignSystem.Spacing.md) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(Color.vendaLine)
                    .frame(height: 16)
                
                RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                    .fill(Color.vendaLine)
                    .frame(height: 40)
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .fill(Color.vendaLine)
                        .frame(height: 12)
                    
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                        .fill(Color.vendaLine)
                        .frame(width: 60, height: 12)
                }
            }
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }
}

/// Loading overlay for full-screen operations
struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                ProgressView()
                    .tint(.vendaForest)
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.vendaInk)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }
}

/// Error state card for displaying errors with recovery actions
struct ErrorStateCard: View {
    let title: String
    let message: String
    let icon: String = "exclamationmark.triangle.fill"
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VendaCard(accentColor: .vendaEmber) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.vendaEmber)
                    .frame(
                        width: DesignSystem.ComponentSize.avatarLarge,
                        height: DesignSystem.ComponentSize.avatarLarge
                    )
                    .background(Color.vendaEmberLt)
                    .cornerRadius(DesignSystem.Radius.lg)
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(title)
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(.vendaInk)
                    Text(message)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.vendaInkMid)
                        .multilineTextAlignment(.center)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    VendaButton(
                        title: actionTitle,
                        action: action,
                        style: .danger,
                        size: .medium
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
}

/// Success state card for confirming successful actions
struct SuccessStateCard: View {
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        VendaCard(accentColor: .vendaForest) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.vendaForest)
                    .frame(
                        width: DesignSystem.ComponentSize.avatarLarge,
                        height: DesignSystem.ComponentSize.avatarLarge
                    )
                    .background(Color.vendaForestLt)
                    .cornerRadius(DesignSystem.Radius.lg)
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(title)
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(.vendaInk)
                    Text(message)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.vendaInkMid)
                        .multilineTextAlignment(.center)
                }
                
                if let actionTitle = actionTitle, let action = action {
                    VendaButton(
                        title: actionTitle,
                        action: action,
                        style: .primary,
                        size: .medium
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
}

/// Toast notification for quick feedback
struct ToastNotification: View {
    let message: String
    let type: NotificationType
    var icon: String? = nil
    
    enum NotificationType {
        case success
        case error
        case warning
        case info
        
        var backgroundColor: Color {
            switch self {
            case .success: return Color.vendaForest
            case .error: return Color.vendaEmber
            case .warning: return Color.vendaOchre
            case .info: return Color.vendaForest
            }
        }
        
        var iconName: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon ?? type.iconName)
                .font(.system(size: DesignSystem.ComponentSize.iconMedium, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.white)
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .padding(DesignSystem.Spacing.md)
        .background(type.backgroundColor)
        .cornerRadius(DesignSystem.Radius.md)
        .shadow(
            color: type.backgroundColor.opacity(0.3),
            radius: DesignSystem.Shadow.elevated.radius,
            x: 0,
            y: DesignSystem.Shadow.elevated.y
        )
    }
}

// MARK: - Shimmering Extension
extension View {
    func shimmering() -> some View {
        modifier(ShimmeringModifier())
    }
}

private struct ShimmeringModifier: ViewModifier {
    @State private var isShimmering = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.3),
                        Color.white.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: isShimmering ? 300 : -300)
                .animation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false),
                    value: isShimmering
                )
            )
            .onAppear { isShimmering = true }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.lg) {
            SkeletonCard()
            SkeletonCard()
            SkeletonCard()
            
            ErrorStateCard(
                title: "Something went wrong",
                message: "An error occurred while processing your request. Please try again.",
                actionTitle: "Retry"
            )
            
            SuccessStateCard(
                title: "Success!",
                message: "Your sale has been completed successfully.",
                actionTitle: "Continue"
            )
            
            ToastNotification(
                message: "Product added to cart",
                type: .success
            )
            
            ToastNotification(
                message: "Network error. Please check your connection.",
                type: .error
            )
        }
        .padding(DesignSystem.Spacing.lg)
    }
    .background(Color.vendaSand)
}

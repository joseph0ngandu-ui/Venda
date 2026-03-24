import SwiftUI

/// Reusable badge component for tags, statuses, and labels
struct VendaBadge: View {
    let title: String
    var style: BadgeStyle = .default_
    var size: BadgeSize = .medium
    var dismissAction: (() -> Void)? = nil
    
    enum BadgeStyle {
        case default_    // Green/Forest
        case primary     // Forest (main)
        case secondary   // Ochre (secondary)
        case warning     // Ochre (warning)
        case error       // Ember (error)
        case neutral     // Gray (neutral)
        
        var backgroundColor: Color {
            switch self {
            case .default_, .primary: return Color.vendaForestLt
            case .secondary: return Color.vendaOchreLt
            case .warning: return Color.vendaOchreLt
            case .error: return Color.vendaEmberLt
            case .neutral: return Color.vendaParchment
            }
        }
        
        var textColor: Color {
            switch self {
            case .default_, .primary: return .vendaForestDk
            case .secondary, .warning: return .vendaOchreDk
            case .error: return .vendaEmber
            case .neutral: return .vendaInk
            }
        }
    }
    
    enum BadgeSize {
        case small
        case medium
        case large
        
        var font: Font {
            switch self {
            case .small: return DesignSystem.Typography.captionSmall
            case .medium: return DesignSystem.Typography.caption
            case .large: return DesignSystem.Typography.buttonSmall
            }
        }
        
        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (DesignSystem.Spacing.sm, DesignSystem.Spacing.xs)
            case .medium: return (DesignSystem.Spacing.md, DesignSystem.Spacing.xs)
            case .large: return (DesignSystem.Spacing.lg, DesignSystem.Spacing.sm)
            }
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Text(title)
                .font(size.font)
                .fontWeight(.semibold)
                .foregroundColor(style.textColor)
            
            if let dismissAction = dismissAction {
                Button(action: dismissAction) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(style.textColor.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(style.backgroundColor)
        .cornerRadius(DesignSystem.Radius.full)
        .accessibilityLabel("Badge: \(title)")
    }
}

/// Status badge (specialized)
struct StatusBadge: View {
    let status: String
    var isActive: Bool = true
    
    var backgroundColor: Color {
        switch status.lowercased() {
        case "active", "completed", "matched": return Color.vendaForestLt
        case "pending", "processing": return Color.vendaOchreLt
        case "inactive", "failed", "unmatched": return Color.vendaEmberLt
        default: return Color.vendaParchment
        }
    }
    
    var textColor: Color {
        switch status.lowercased() {
        case "active", "completed", "matched": return .vendaForestDk
        case "pending", "processing": return .vendaOchreDk
        case "inactive", "failed", "unmatched": return .vendaEmber
        default: return .vendaInk
        }
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(textColor)
                .frame(width: 6, height: 6)
            
            Text(status.capitalized)
                .font(DesignSystem.Typography.captionSmall)
                .fontWeight(.semibold)
                .foregroundColor(textColor)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(backgroundColor)
        .cornerRadius(DesignSystem.Radius.full)
        .accessibilityLabel("Status: \(status)")
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Badge Styles").font(DesignSystem.Typography.label)
            HStack(spacing: DesignSystem.Spacing.md) {
                VendaBadge(title: "Default", style: .default_)
                VendaBadge(title: "Primary", style: .primary)
                VendaBadge(title: "Secondary", style: .secondary)
            }
            HStack(spacing: DesignSystem.Spacing.md) {
                VendaBadge(title: "Warning", style: .warning)
                VendaBadge(title: "Error", style: .error)
                VendaBadge(title: "Neutral", style: .neutral)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Badge Sizes").font(DesignSystem.Typography.label)
            HStack(spacing: DesignSystem.Spacing.md) {
                VendaBadge(title: "Small", size: .small)
                VendaBadge(title: "Medium", size: .medium)
                VendaBadge(title: "Large", size: .large)
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Specialized Badges").font(DesignSystem.Typography.label)
            HStack(spacing: DesignSystem.Spacing.md) {
                PaymentMethodBadge(method: "Cash")
                PaymentMethodBadge(method: "Mobile Money")
                PaymentMethodBadge(method: "Credit")
            }
        }
        
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Status Badges").font(DesignSystem.Typography.label)
            HStack(spacing: DesignSystem.Spacing.md) {
                StatusBadge(status: "Active")
                StatusBadge(status: "Pending")
                StatusBadge(status: "Inactive")
            }
        }
        
        Spacer()
    }
    .padding(DesignSystem.Spacing.lg)
    .background(Color.vendaSand)
}

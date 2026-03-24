import SwiftUI

/// Unified search field component for consistent search UI across the app
struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    var isLoading: Bool = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: DesignSystem.ComponentSize.iconSmall, weight: .medium))
                .foregroundColor(.vendaInkLt)
            
            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.vendaInk)
            
            if isLoading {
                ProgressView()
                    .tint(.vendaForest)
            } else if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: DesignSystem.ComponentSize.iconSmall))
                        .foregroundColor(.vendaInkLt)
                }
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(Color.vendaWhite)
        .cornerRadius(DesignSystem.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .stroke(Color.vendaLine, lineWidth: 1)
        )
        .accessibilityLabel("Search")
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        SearchField(text: .constant(""), placeholder: "Search products")
        SearchField(text: .constant("Wash"), placeholder: "Search products")
    }
    .padding(DesignSystem.Spacing.lg)
    .background(Color.vendaSand)
}

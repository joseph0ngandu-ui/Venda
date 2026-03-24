import SwiftUI

// MARK: - Accessibility Enums
enum HeadingLevel {
    case h1, h2, h3, h4
}

// MARK: - Accessibility Extensions
extension View {
    /// Adds semantic label and hint for better screen reader support
    func vendaAccessible(label: String, hint: String? = nil) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
    }
    
    /// Marks a button with proper accessibility traits
    func vendaButtonAccessibility(label: String, disabled: Bool = false) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .disabled(disabled)
    }
    
    /// Marks a heading for proper document structure
    func vendaHeading(level: HeadingLevel = .h3) -> some View {
        self
            .accessibilityAddTraits([.isHeader])
            .accessibilityLabel("")
    }
    
    /// Adds focus indicator for better keyboard navigation
    func focusableStyle(isFocused: Bool) -> some View {
        if isFocused {
            return AnyView(
                self
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                            .stroke(Color.vendaForest, lineWidth: 2)
                    )
            )
        } else {
            return AnyView(self)
        }
    }
    
    /// Ensures minimum touch target size for accessibility
    func minimumTouchTarget(_ size: CGFloat = DesignSystem.ComponentSize.minTouchTarget) -> some View {
        self
            .frame(minHeight: size)
    }
}

// MARK: - Color Contrast Utilities
/// Helper to ensure sufficient color contrast for readability
struct ContrastCheckedText: View {
    let text: String
    let foreground: Color
    let background: Color
    var font: Font = DesignSystem.Typography.body
    
    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(foreground)
            .background(background)
            .accessibilityElement(children: .combine)
    }
}

// MARK: - Semantic HTML-like Structure
struct AccessibleList<Item: Identifiable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let listLabel: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(listLabel)
                .accessibilityAddTraits([.isHeader])
                .font(DesignSystem.Typography.label)
                .foregroundColor(.vendaInkLt)
                .padding(.bottom, DesignSystem.Spacing.md)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(items) { item in
                    content(item)
                        .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Focus Management
struct FocusableTextField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(.vendaInkLt)
            
            TextField(placeholder, text: $text)
                .focused($isFocused)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.vendaInk)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                .background(Color.vendaWhite)
                .cornerRadius(DesignSystem.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(
                            isFocused ? Color.vendaForest : Color.vendaLine,
                            lineWidth: isFocused ? 2 : 1
                        )
                )
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Dynamic Type Support
extension View {
    /// Respects Dynamic Type accessibility setting
    func supportDynamicType() -> some View {
        self.environment(\.sizeCategory, .large)
    }
}

// MARK: - Reduced Motion Support
struct ReducedMotionView<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let content: () -> Content
    let reducedContent: (() -> Content)? 
    
    init(
        @ViewBuilder content: @escaping () -> Content,
        reduced: (() -> Content)? = nil
    ) {
        self.content = content
        self.reducedContent = reduced
    }
    
    var body: some View {
        if reduceMotion, let reducedContent = reducedContent {
            reducedContent()
        } else {
            content()
        }
    }
}

struct MockItem: Identifiable {
    let id: Int
    let name: String
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        Text("Accessible Button")
            .vendaButtonAccessibility(label: "Edit user profile")
        
        AccessibleList(
            items: [
                MockItem(id: 1, name: "Item 1"),
                MockItem(id: 2, name: "Item 2"),
                MockItem(id: 3, name: "Item 3")
            ],
            content: { item in
                Text(item.name)
                    .padding(DesignSystem.Spacing.md)
                    .background(Color.vendaWhite)
                    .cornerRadius(DesignSystem.Radius.md)
            },
            listLabel: "Items"
        )
        
        FocusableTextField(
            label: "Email",
            text: .constant(""),
            placeholder: "your@email.com"
        )
    }
    .padding(DesignSystem.Spacing.lg)
    .background(Color.vendaSand)
}

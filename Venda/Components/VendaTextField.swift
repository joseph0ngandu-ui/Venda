import SwiftUI

/// Unified text input component for the entire app
struct VendaTextField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var disabled: Bool = false
    var helperText: String?
    var errorMessage: String?
    var onEditingChanged: (Bool) -> Void = { _ in }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            // Label
            if let label = label {
                Text(label)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(.vendaInkLt)
            }
            
            // Input Field
            ZStack(alignment: .trailing) {
                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInk)
                    } else {
                        TextField(placeholder, text: $text)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInk)
                            .keyboardType(keyboardType)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                
                // Clear button
                if !text.isEmpty && !disabled {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: DesignSystem.ComponentSize.iconSmall))
                            .foregroundColor(.vendaInkLt)
                            .padding(.trailing, DesignSystem.Spacing.lg)
                    }
                }
            }
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(
                        errorMessage != nil ? Color.vendaEmber : Color.vendaLine,
                        lineWidth: 1
                    )
            )
            .opacity(disabled ? DesignSystem.Opacity.disabled : 1)
            
            // Helper or Error Text
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaEmber)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaInkMid)
            }
        }
        .disabled(disabled)
    }
}

/// Unified numeric input component
struct VendaNumberField: View {
    let label: String?
    let placeholder: String
    @Binding var value: Decimal
    var disabled: Bool = false
    var helperText: String?
    var errorMessage: String?
    var minValue: Decimal? = nil
    var maxValue: Decimal? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let label = label {
                Text(label)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(.vendaInkLt)
            }
            
            ZStack(alignment: .leading) {
                if value == 0 {
                    Text(placeholder)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.vendaInkLt)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                
                TextField("", value: $value, format: .number)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.vendaInk)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.md)
            }
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(
                        errorMessage != nil ? Color.vendaEmber : Color.vendaLine,
                        lineWidth: 1
                    )
            )
            .opacity(disabled ? DesignSystem.Opacity.disabled : 1)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaEmber)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaInkMid)
            }
        }
        .disabled(disabled)
    }
}

/// Unified password field with visibility toggle
struct VendaPasswordField: View {
    let label: String?
    let placeholder: String
    @Binding var text: String
    var helperText: String?
    var errorMessage: String?
    @State private var showPassword = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            if let label = label {
                Text(label)
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(.vendaInkLt)
            }
            
            ZStack(alignment: .trailing) {
                Group {
                    if showPassword {
                        TextField(placeholder, text: $text)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInk)
                            .textInputAutocapitalization(.none)
                            .disableAutocorrection(true)
                    } else {
                        SecureField(placeholder, text: $text)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInk)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.md)
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: DesignSystem.ComponentSize.iconSmall, weight: .semibold))
                        .foregroundColor(.vendaInkMid)
                        .padding(.trailing, DesignSystem.Spacing.lg)
                }
            }
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(
                        errorMessage != nil ? Color.vendaEmber : Color.vendaLine,
                        lineWidth: 1
                    )
            )
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaEmber)
            } else if let helperText = helperText {
                Text(helperText)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaInkMid)
            }
        }
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spacing.lg) {
        VendaTextField(
            label: "Full Name",
            placeholder: "Enter your name",
            text: .constant("")
        )
        
        VendaNumberField(
            label: "Price",
            placeholder: "0.00",
            value: .constant(0),
            helperText: "Enter the product price"
        )
        
        VendaPasswordField(
            label: "Password",
            placeholder: "Enter password",
            text: .constant("")
        )
        
        VendaTextField(
            label: "Email",
            placeholder: "your@email.com",
            text: .constant("invalid"),
            errorMessage: "Please enter a valid email"
        )
    }
    .padding(DesignSystem.Spacing.lg)
    .background(Color.vendaSand)
}

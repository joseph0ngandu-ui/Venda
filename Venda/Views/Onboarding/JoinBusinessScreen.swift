import SwiftUI

struct JoinBusinessScreen: View {
    var onSubmit: (String, String) async -> String?
    var onBack: () -> Void
    
    @State private var companyCode: String = ""
    @State private var staffPin: String = ""
    @State private var isJoining: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.md)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Join Business")
                        .font(.custom("Fraunces", size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.vendaInk)
                    
                    Text("Enter the company code and your pre-assigned staff PIN.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.vendaInkMid)
                }
                .padding(.bottom, DesignSystem.Spacing.md)
                
                // Form
                VStack(spacing: DesignSystem.Spacing.xl) {
                    FormField(
                        label: "Company Code",
                        placeholder: "e.g. VND-5028",
                        text: $companyCode,
                        autocapitalization: .characters
                    )
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Staff PIN")
                            .font(DesignSystem.Typography.label)
                            .foregroundColor(.vendaInkMid)
                        
                        SecureField("••••", text: $staffPin)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.vendaInk)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .frame(height: DesignSystem.ComponentSize.buttonHeightLarge)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .stroke(Color.vendaLine, lineWidth: 1)
                            )
                            .onTapGesture { } // Prevent keyboard from appearing
                    }
                }
                
                if let error = errorMessage {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaEmber)
                    .padding(.top, DesignSystem.Spacing.xs)
                }
                
                Spacer()
                
                VendaButton(
                    title: isJoining ? "Verifying..." : "Join Business",
                    action: handleJoin
                )
                .disabled(companyCode.isEmpty || staffPin.isEmpty || isJoining)
                .padding(.bottom, DesignSystem.Spacing.md)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
        }
        .navigationBarHidden(true)
    }
    
    private func handleJoin() {
        isJoining = true
        errorMessage = nil

        Task {
            let result = await onSubmit(
                companyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(),
                staffPin
            )
            if let result {
                errorMessage = result
            }
            isJoining = false
        }
    }
}

private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var autocapitalization: TextInputAutocapitalization = .never
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(.vendaInkMid)
            
            TextField(placeholder, text: $text)
                .font(DesignSystem.Typography.body)
                .foregroundColor(.vendaInk)
                .textInputAutocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .frame(height: DesignSystem.ComponentSize.buttonHeightLarge)
                .background(Color.vendaWhite)
                .cornerRadius(DesignSystem.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                        .stroke(Color.vendaLine, lineWidth: 1)
                )
        }
    }
}

#Preview {
    JoinBusinessScreen(onSubmit: { _, _ in nil }, onBack: {})
}

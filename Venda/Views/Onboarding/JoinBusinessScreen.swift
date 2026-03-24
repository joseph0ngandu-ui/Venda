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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Join Business")
                        .font(.custom("Fraunces", size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.vendaInk)
                    
                    Text("Enter the company code and your pre-assigned staff PIN.")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }
                .padding(.bottom, 16)
                
                // Form
                VStack(spacing: 20) {
                    FormField(
                        label: "Company Code",
                        placeholder: "e.g. VND-5028",
                        text: $companyCode,
                        autocapitalization: .characters
                    )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Staff PIN")
                            .font(.system(size: 13, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInkMid)
                        
                        SecureField("••••", text: $staffPin)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.vendaInk)
                            .keyboardType(.numberPad)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Color.vendaWhite)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.vendaLine, lineWidth: 1)
                            )
                    }
                }
                
                if let error = errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vendaEmber)
                    .padding(.top, 4)
                }
                
                Spacer()
                
                VendaButton(
                    title: isJoining ? "Verifying..." : "Join Business",
                    action: handleJoin
                )
                .disabled(companyCode.isEmpty || staffPin.isEmpty || isJoining)
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
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
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundColor(.vendaInkMid)
            
            TextField(placeholder, text: $text)
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundColor(.vendaInk)
                .textInputAutocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(Color.vendaWhite)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.vendaLine, lineWidth: 1)
                )
        }
    }
}

#Preview {
    JoinBusinessScreen(onSubmit: { _, _ in nil }, onBack: {})
}

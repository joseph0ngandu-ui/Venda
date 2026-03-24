import SwiftUI
import LocalAuthentication

struct LoginScreen: View {
    var onSubmit: (String, String) async -> String?
    var onBack: () -> Void

    @State private var showError = false
    @State private var isFaceIDAvailable = false
    @State private var phone = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.vendaForest
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxxl)

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text("venda")
                        .font(.custom("Fraunces", size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Sign back into your business")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(showError ? .vendaEmberLt : .white.opacity(0.8))
                }
                .padding(.bottom, DesignSystem.Spacing.xxl)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Phone Number")
                        .font(DesignSystem.Typography.label)
                        .foregroundColor(.white.opacity(0.7))

                    TextField("260971234567", text: $phone)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.phonePad)
                        .disableAutocorrection(true)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .frame(height: DesignSystem.ComponentSize.buttonHeightLarge)
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(DesignSystem.Radius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                                .stroke(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .onTapGesture { } // Prevent keyboard from appearing
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)

                // PIN Pad tailored for Dark Background
                StaffPINPadDark(
                    onComplete: handlePinEntry,
                    maxDigits: 4,
                    hasError: showError,
                    isFaceIDAvailable: isFaceIDAvailable,
                    onFaceIDTap: authenticateWithBiometrics
                )
                .modifier(ShakeEffect(animatableData: showError ? 1 : 0))
                .disabled(isSubmitting)

                if let errorMessage {
                    Text(errorMessage)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaEmberLt)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.lg)
                } else if isSubmitting {
                    ProgressView("Signing in...")
                        .tint(.white)
                        .padding(.top, DesignSystem.Spacing.lg)
                } else {
                    Text("Use the business phone number linked to your account.")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.top, DesignSystem.Spacing.lg)
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            checkBiometricAvailability()
        }
    }

    private func handlePinEntry(_ pin: String) {
        let normalizedPhone = phone
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedPhone.isEmpty else {
            showValidationError("Enter the business phone number before your PIN.")
            return
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            let result = await onSubmit(normalizedPhone, pin)
            isSubmitting = false

            if let result {
                showValidationError(result)
            }
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            isFaceIDAvailable = true
        }
    }

    private func authenticateWithBiometrics() {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Unlock Venda to access your business."

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        errorMessage = "Biometric login will unlock once this device has a saved session."
                    } else {
                        errorMessage = "Biometric verification was cancelled. You can still sign in with your PIN."
                    }
                }
            }
        }
    }

    private func showValidationError(_ message: String) {
        errorMessage = message

        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
            showError = true
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showError = false
        }
    }
}

// A distinct PIN Pad variant for the dark green login screen
private struct StaffPINPadDark: View {
    @State private var pinInput: String = ""
    var onComplete: (String) -> Void
    var maxDigits: Int
    var hasError: Bool
    var isFaceIDAvailable: Bool
    var onFaceIDTap: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                Spacer()
                ForEach(0..<maxDigits, id: \.self) { index in
                    Circle()
                        .stroke(
                            hasError ? Color.vendaEmber : (index < pinInput.count ? Color.clear : Color.white.opacity(0.3)),
                            lineWidth: 2
                        )
                        .background(
                            Circle()
                                .fill(hasError ? Color.vendaEmber : (index < pinInput.count ? Color.white : Color.clear))
                        )
                        .frame(width: 24, height: 24)
                }
                Spacer()
            }
            .padding(.bottom, 32)
            .padding(.horizontal, 16)

            VStack(spacing: 12) {
                ForEach(1...3, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { col in
                            let num = (row - 1) * 3 + col
                            PINButtonDark(number: String(num)) {
                                appendDigit(String(num))
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    // Bottom Left: FaceID (if available) or empty placeholder
                    if isFaceIDAvailable {
                        Button(action: onFaceIDTap) {
                            Image(systemName: "faceid")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.white)
                                .frame(height: 64)
                                .frame(maxWidth: .infinity)
                                .background(Color.clear)
                                .contentShape(Rectangle())
                        }
                    } else {
                        Button(action: {}) {
                            Text("")
                                .frame(height: 64)
                                .frame(maxWidth: .infinity)
                                .background(Color.clear)
                                .cornerRadius(12)
                        }
                        .disabled(true)
                    }
                    
                    PINButtonDark(number: "0") {
                        appendDigit("0")
                    }
                    
                    // Bottom Right: Delete
                    Button(action: {
                        if !pinInput.isEmpty {
                            pinInput.removeLast()
                        }
                    }) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(height: 64)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 32)
        }
    }

    private func appendDigit(_ digit: String) {
        if hasError { return } // Block input during error shake
        guard pinInput.count < maxDigits else { return }
        pinInput.append(digit)
        if pinInput.count == maxDigits {
            // Short delay so user sees dot filled
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                onComplete(pinInput)
                if hasError { pinInput = "" }
            }
        }
    }
}

private struct PINButtonDark: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(DesignSystem.Typography.h1)
                .foregroundColor(.white)
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.md)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    LoginScreen(onSubmit: { _, _ in nil }, onBack: {})
}

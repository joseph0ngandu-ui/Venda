import SwiftUI
import LocalAuthentication

struct LoginScreen: View {
    var onComplete: (String) -> Void
    var onBack: () -> Void

    @State private var showError = false
    @State private var isFaceIDAvailable = false

    var body: some View {
        ZStack {
            Color.vendaForest
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 60)

                VStack(spacing: 12) {
                    Text("venda")
                        .font(.custom("Fraunces", size: 32))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Enter your PIN")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(showError ? .vendaEmberLt : .white.opacity(0.8))
                }
                .padding(.bottom, 60)

                // PIN Pad tailored for Dark Background
                StaffPINPadDark(
                    onComplete: handlePinEntry,
                    maxDigits: 4,
                    hasError: showError,
                    isFaceIDAvailable: isFaceIDAvailable,
                    onFaceIDTap: authenticateWithBiometrics
                )
                .modifier(ShakeEffect(animatableData: showError ? 1 : 0))

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            checkBiometricAvailability()
            
            // Auto-trigger FaceID on appear if available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if isFaceIDAvailable {
                    authenticateWithBiometrics()
                }
            }
        }
    }

    private func handlePinEntry(_ pin: String) {
        // Mock PIN check (e.g. 1234)
        if pin == "1234" {
            onComplete(pin)
        } else {
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

            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        // Bypass PIN entry on successful biometric auth
                        onComplete("biometric")
                    } else {
                        // User cancelled or it failed, just let them use PIN
                        print("Biometric authentication failed")
                    }
                }
            }
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
                    // Bottom Left: FaceID (if available) or empty space
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
                        Spacer()
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
                .font(.system(size: 28, weight: .medium, design: .default))
                .foregroundColor(.white)
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    LoginScreen(onComplete: { _ in }, onBack: {})
}

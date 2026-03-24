import SwiftUI

struct PINSetupScreen: View {
    var onComplete: (String) async -> String?
    var onBack: () -> Void

    @State private var firstPin: String? = nil
    @State private var currentStepTitle = "Create a 4-digit PIN"
    @State private var currentStepSubtitle = "You'll use this to log in and approve discounts."
    @State private var showError = false
    @State private var pinPadId = UUID()
    @State private var isSubmitting = false

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.vendaInk)
                    }
                    Spacer()
                    ProgressDot(isActive: true)
                    ProgressDot(isActive: true)
                    ProgressDot(isActive: false)
                    Spacer()
                    // Hidden view to balance the back button
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)

                VStack(spacing: 12) {
                    Text(currentStepTitle)
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundColor(showError ? .vendaEmber : .vendaInk)
                    
                    Text(currentStepSubtitle)
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(showError ? .vendaEmber : .vendaInkMid)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.bottom, 60)

                StaffPINPad(
                    onComplete: handlePinEntry,
                    maxDigits: 4
                )
                .id(pinPadId)
                .modifier(ShakeEffect(animatableData: showError ? 1 : 0))
                .disabled(isSubmitting)

                if isSubmitting {
                    ProgressView("Creating your workspace...")
                        .tint(.vendaForest)
                        .padding(.top, 24)
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }

    private func handlePinEntry(_ pin: String) {
        if let existing = firstPin {
            if pin == existing {
                isSubmitting = true
                Task {
                    let submissionError = await onComplete(pin)
                    isSubmitting = false

                    if let submissionError {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                            showError = true
                            currentStepTitle = "We couldn't finish setup"
                            currentStepSubtitle = submissionError
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                            firstPin = nil
                            showError = false
                            currentStepTitle = "Create a 4-digit PIN"
                            currentStepSubtitle = "You'll use this to log in and approve discounts."
                            pinPadId = UUID()
                        }
                    }
                }
            } else {
                // Mismatch
                withAnimation(.spring(response: 0.3, dampingFraction: 0.3)) {
                    showError = true
                    currentStepTitle = "PINs don't match"
                    currentStepSubtitle = "Please try again."
                }
                // Reset after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    firstPin = nil
                    showError = false
                    currentStepTitle = "Create a 4-digit PIN"
                    currentStepSubtitle = "You'll use this to log in and approve discounts."
                    pinPadId = UUID()
                }
            }
        } else {
            firstPin = pin
            currentStepTitle = "Confirm your PIN"
            currentStepSubtitle = "Enter it one more time."
            pinPadId = UUID()
        }
    }
}

private struct ProgressDot: View {
    let isActive: Bool
    var body: some View {
        Circle()
            .fill(isActive ? Color.vendaForest : Color.vendaLine)
            .frame(width: 8, height: 8)
    }
}

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

#Preview {
    PINSetupScreen(onComplete: { _ in nil }, onBack: {})
}

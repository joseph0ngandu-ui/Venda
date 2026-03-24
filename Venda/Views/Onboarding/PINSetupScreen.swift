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
    @State private var errorRecoveryTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: handleBack) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.button)
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
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xxxl)

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(currentStepTitle)
                        .font(DesignSystem.Typography.h2)
                        .foregroundColor(showError ? .vendaEmber : .vendaInk)
                    
                    Text(currentStepSubtitle)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(showError ? .vendaEmber : .vendaInkMid)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Spacing.xxxl)
                }
                .padding(.bottom, DesignSystem.Spacing.xxxl)

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
                        .padding(.top, DesignSystem.Spacing.xl)
                } else if showError {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text(currentStepSubtitle)
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(.vendaEmber)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.top, DesignSystem.Spacing.lg)
                        
                        Button(action: handleBack) {
                            Text("Go back to business details")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.vendaForest)
                                .frame(maxWidth: .infinity)
                                .frame(height: DesignSystem.ComponentSize.buttonHeightSmall)
                                .background(Color.vendaForestLt)
                                .cornerRadius(DesignSystem.Radius.md)
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.bottom, DesignSystem.Spacing.lg)
                    }
                }

                Spacer()
            }
        }
        .navigationBarHidden(true)
        .onDisappear {
            errorRecoveryTask?.cancel()
        }
    }
    
    private func handleBack() {
        // Cancel any pending error recovery
        errorRecoveryTask?.cancel()
        errorRecoveryTask = nil
        onBack()
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

                        // Cancel previous recovery task if any
                        errorRecoveryTask?.cancel()
                        
                        // Schedule auto-reset after 3 seconds instead of 1.6
                        errorRecoveryTask = Task {
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            if !Task.isCancelled {
                                resetPINEntry()
                            }
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
                errorRecoveryTask?.cancel()
                errorRecoveryTask = Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if !Task.isCancelled {
                        resetPINEntry()
                    }
                }
            }
        } else {
            firstPin = pin
            currentStepTitle = "Confirm your PIN"
            currentStepSubtitle = "Enter it one more time."
            pinPadId = UUID()
        }
    }
    
    private func resetPINEntry() {
        firstPin = nil
        showError = false
        currentStepTitle = "Create a 4-digit PIN"
        currentStepSubtitle = "You'll use this to log in and approve discounts."
        pinPadId = UUID()
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

import SwiftUI

struct WelcomeScreen: View {
    var onGetStarted: () -> Void
    var onJoinBusiness: () -> Void
    var onLogin: () -> Void

    var body: some View {
        ZStack {
            Color.vendaForest
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and Tagline
                VStack(spacing: 12) {
                    Text("venda")
                        .font(.custom("Fraunces", size: 48))
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Run your business from your phone.")
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.bottom, 64)

                // Feature Pills
                VStack(spacing: DesignSystem.Spacing.lg) {
                    FeaturePill(text: "📦 Track every sale")
                    FeaturePill(text: "💳 Cash & mobile money")
                    FeaturePill(text: "📊 See what's working")
                }
                .padding(.bottom, DesignSystem.Spacing.xxxl)

                Spacer()

                // Actions
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: onGetStarted) {
                        Text("Set up my business")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.vendaForest)
                            .frame(height: DesignSystem.ComponentSize.buttonHeightLarge)
                            .frame(maxWidth: .infinity)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.lg)
                    }
                    
                    Button(action: onJoinBusiness) {
                        Text("Join existing business")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.vendaWhite)
                            .frame(height: DesignSystem.ComponentSize.buttonHeightLarge)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(DesignSystem.Radius.lg)
                    }

                    Button(action: onLogin) {
                        Text("I already have an account")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, DesignSystem.Spacing.sm)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
        }
    }
}

private struct FeaturePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DesignSystem.Typography.body)
            .foregroundColor(.white)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    WelcomeScreen(onGetStarted: {}, onJoinBusiness: {}, onLogin: {})
}

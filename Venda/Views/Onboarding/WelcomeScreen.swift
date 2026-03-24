import SwiftUI

struct WelcomeScreen: View {
    var onGetStarted: () -> Void
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
                VStack(spacing: 16) {
                    FeaturePill(text: "📦 Track every sale")
                    FeaturePill(text: "💳 Cash & mobile money")
                    FeaturePill(text: "📊 See what's working")
                }
                .padding(.bottom, 80)

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button(action: onGetStarted) {
                        Text("Set up my business")
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(.vendaForest)
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(14)
                    }

                    Button(action: onLogin) {
                        Text("I already have an account")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.white)
                            .frame(height: 52)
                            .frame(maxWidth: .infinity)
                            .background(Color.clear)
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

private struct FeaturePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium, design: .default))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.15))
            .clipShape(Capsule())
    }
}

#Preview {
    WelcomeScreen(onGetStarted: {}, onLogin: {})
}

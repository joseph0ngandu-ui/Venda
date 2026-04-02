import SwiftUI

struct AppShellView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

    private var resumeRoute: OnboardingFlow.Route? {
        guard appState.pendingOnboardingState?.step == .firstProduct else { return nil }
        return .firstProduct
    }

    var body: some View {
        ZStack {
            Group {
                if appState.isBootstrapping {
                    Color.vendaForest
                        .overlay(
                            ProgressView("Preparing your workspace...")
                                .tint(.white)
                                .foregroundColor(.white)
                        )
                } else if !appState.isAuthenticated || appState.shouldResumeOnboarding {
                    OnboardingFlow(resumeRoute: resumeRoute)
                        .transition(.opacity)
                } else {
                    VendaTabBar()
                        .transition(.opacity)
                }
            }
            .animation(
                .easeInOut(duration: 0.3),
                value: [appState.isBootstrapping, appState.isAuthenticated, appState.shouldResumeOnboarding]
            )

            if showSplash {
                SplashScreen {
                    withAnimation {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

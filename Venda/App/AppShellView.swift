import SwiftUI

struct AppShellView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSplash = true

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
                } else if appState.isAuthenticated {
                    VendaTabBar()
                        .transition(.opacity)
                } else {
                    OnboardingFlow()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appState.isAuthenticated)

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

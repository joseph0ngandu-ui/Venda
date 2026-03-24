import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen(
                onGetStarted: { path.append(Route.register) },
                onLogin: { path.append(Route.login) }
            )
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .register:
                    BusinessRegistrationScreen { name, owner, phone, type in
                        // Typically, we'd save this temporarily in a view model
                        // For the mock, we pass to PIN
                        path.append(Route.pinSetup(name: name, owner: owner, phone: phone, type: type))
                    }
                case .pinSetup(_, _, _, _):
                    PINSetupScreen(
                        onComplete: { pin in
                            // Complete Registration Logic here (e.g. API call/CoreData)
                            path.append(Route.firstProduct)
                        },
                        onBack: { path.removeLast() }
                    )
                case .firstProduct:
                    FirstProductScreen(
                        onComplete: { product in
                            // Save product
                            completeOnboarding()
                        },
                        onSkip: {
                            completeOnboarding()
                        }
                    )
                case .login:
                    // Fallback simpler PIN entry for existing users
                    LoginScreen(
                        onComplete: { pin in
                            // Verify PIN
                            appState.isAuthenticated = true
                        },
                        onBack: { path.removeLast() }
                    )
                }
            }
        }
    }
    
    private func completeOnboarding() {
        appState.isAuthenticated = true
    }
    
    enum Route: Hashable {
        case register
        case pinSetup(name: String, owner: String, phone: String, type: String)
        case firstProduct
        case login
    }
}

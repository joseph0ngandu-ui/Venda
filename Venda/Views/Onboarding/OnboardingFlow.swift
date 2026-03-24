import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen(
                onGetStarted: { path.append(Route.register) },
                onJoinBusiness: { path.append(Route.joinBusiness) },
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
                case .joinBusiness:
                    JoinBusinessScreen(
                        onSuccess: {
                            // Staff member successfully joined
                            let mockUser = CurrentUser(id: UUID(), name: "Cashier", role: .cashier, companyCode: "VND-123")
                            appState.login(user: mockUser)
                        },
                        onBack: { path.removeLast() }
                    )
                case .login:
                    // Fallback simpler PIN entry for existing users
                    LoginScreen(
                        onComplete: { pin in
                            // For mocking purposes:
                            let mockUser = CurrentUser(id: UUID(), name: "Staff Member", role: .cashier, companyCode: "VND-123")
                            appState.login(user: mockUser)
                        },
                        onBack: { path.removeLast() }
                    )
                }
            }
        }
    }
    
    private func completeOnboarding(role: StaffRole = .admin) {
        let mockOwner = CurrentUser(id: UUID(), name: "Owner", role: role, companyCode: "VND-123")
        appState.login(user: mockOwner)
    }
    
    enum Route: Hashable {
        case register
        case joinBusiness
        case pinSetup(name: String, owner: String, phone: String, type: String)
        case firstProduct
        case login
    }
}

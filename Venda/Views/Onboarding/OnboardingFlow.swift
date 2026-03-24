import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stockViewModel: StockViewModel
    @State private var path = NavigationPath()
    @State private var registrationDraft: RegistrationDraft?
    @State private var pendingSession: AuthenticatedSession?
    @State private var errorMessage: String?

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
                        registrationDraft = RegistrationDraft(
                            businessName: name,
                            ownerName: owner,
                            phone: phone,
                            businessType: type
                        )
                        path.append(Route.pinSetup(name: name, owner: owner, phone: phone, type: type))
                    }
                case .pinSetup(_, _, _, _):
                    PINSetupScreen(
                        onComplete: { pin in
                            await handleRegistration(pin: pin)
                        },
                        onBack: { path.removeLast() }
                    )
                case .firstProduct:
                    FirstProductScreen(
                        onComplete: { product in
                            completeOnboarding(product: product)
                        },
                        onSkip: {
                            completeOnboarding(product: nil)
                        }
                    )
                case .joinBusiness:
                    JoinBusinessScreen(
                        onSubmit: { companyCode, pin in
                            await handleStaffJoin(companyCode: companyCode, pin: pin)
                        },
                        onBack: { path.removeLast() }
                    )
                case .login:
                    LoginScreen(
                        onSubmit: { phone, pin in
                            await handleMerchantLogin(phone: phone, pin: pin)
                        },
                        onBack: { path.removeLast() }
                    )
                }
            }
            .alert("We couldn't complete that action", isPresented: errorAlertPresented) {
                Button("OK", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorAlertPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { newValue in
                if !newValue {
                    errorMessage = nil
                }
            }
        )
    }

    private func handleRegistration(pin: String) async -> String? {
        guard let registrationDraft else {
            return "We lost your business details. Please go back and try again."
        }

        do {
            let session = try await NetworkService.shared.register(
                businessName: registrationDraft.businessName,
                ownerName: registrationDraft.ownerName,
                businessType: registrationDraft.businessType,
                phone: registrationDraft.phone,
                pin: pin
            )
            pendingSession = session
            path.append(Route.firstProduct)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func handleMerchantLogin(phone: String, pin: String) async -> String? {
        do {
            let session = try await NetworkService.shared.loginMerchant(phone: phone, pin: pin)
            appState.applyAuthenticatedSession(session)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func handleStaffJoin(companyCode: String, pin: String) async -> String? {
        do {
            let session = try await NetworkService.shared.joinBusiness(companyCode: companyCode, pin: pin)
            appState.applyAuthenticatedSession(session)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func completeOnboarding(product: ProductModel?) {
        if let product {
            stockViewModel.addProduct(product)
        }

        if let pendingSession {
            appState.applyAuthenticatedSession(pendingSession)
        } else {
            errorMessage = "Your account was created, but we could not restore the session. Please sign in."
        }

        self.pendingSession = nil
        registrationDraft = nil
        path = NavigationPath()
    }
    
    enum Route: Hashable {
        case register
        case joinBusiness
        case pinSetup(name: String, owner: String, phone: String, type: String)
        case firstProduct
        case login
    }
}

private struct RegistrationDraft {
    let businessName: String
    let ownerName: String
    let phone: String
    let businessType: String
}

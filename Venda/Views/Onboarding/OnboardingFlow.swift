import SwiftUI

struct OnboardingFlow: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var stockViewModel: StockViewModel
    @State private var path: [Route]
    @State private var registrationDraft: RegistrationDraft?
    @State private var errorMessage: String?

    init(resumeRoute: Route? = nil) {
        _path = State(initialValue: resumeRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeScreen(
                onGetStarted: { path.append(Route.register) },
                onJoinBusiness: { path.append(Route.joinBusiness) },
                onLogin: { path.append(Route.login) }
            )
            .navigationDestination(for: Route.self, destination: destinationView)
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

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .register:
            registrationScreen
        case .pinSetup:
            pinSetupScreen
        case .firstProduct:
            firstProductScreen
        case .joinBusiness:
            joinBusinessScreen
        case .login:
            loginScreen
        }
    }

    private var registrationScreen: some View {
        BusinessRegistrationScreen(onNext: handleRegistrationDetails)
    }

    private var pinSetupScreen: some View {
        PINSetupScreen(
            onComplete: handleRegistration,
            onBack: popLastRoute
        )
    }

    private var firstProductScreen: some View {
        FirstProductScreen(
            onComplete: completeOnboarding,
            onSkip: skipFirstProduct
        )
    }

    private var joinBusinessScreen: some View {
        JoinBusinessScreen(
            onSubmit: handleStaffJoin,
            onBack: popLastRoute
        )
    }

    private var loginScreen: some View {
        LoginScreen(
            onSubmit: handleMerchantLogin,
            onBack: popLastRoute
        )
    }

    private func handleRegistrationDetails(name: String, owner: String, phone: String, type: String) {
        registrationDraft = RegistrationDraft(
            businessName: name,
            ownerName: owner,
            phone: phone,
            businessType: type
        )
        path.append(Route.pinSetup)
    }

    private func handleRegistration(pin: String) async -> String? {
        guard let registrationDraft else {
            return "We lost your business details. Please go back and try again."
        }

        do {
            try await appState.registerBusiness(
                businessName: registrationDraft.businessName,
                ownerName: registrationDraft.ownerName,
                businessType: registrationDraft.businessType,
                phone: registrationDraft.phone,
                pin: pin
            )
            path.append(Route.firstProduct)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func handleMerchantLogin(phone: String, pin: String) async -> String? {
        do {
            try await appState.loginMerchant(phone: phone, pin: pin)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func handleStaffJoin(companyCode: String, pin: String) async -> String? {
        do {
            try await appState.joinBusiness(companyCode: companyCode, pin: pin)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func skipFirstProduct() {
        completeOnboarding(product: nil)
    }

    private func completeOnboarding(product: ProductModel?) {
        guard appState.isAuthenticated else {
            errorMessage = "Your account was created, but we could not restore the session. Please sign in."
            return
        }

        if let product {
            stockViewModel.addProduct(product)
            SyncEngine.shared.triggerSync()
        }

        appState.completePendingOnboarding()
        registrationDraft = nil
        path = []
    }

    private func popLastRoute() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    enum Route: Hashable {
        case register
        case joinBusiness
        case pinSetup
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

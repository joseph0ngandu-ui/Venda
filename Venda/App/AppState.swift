import Foundation
import Combine

enum StaffRole: String, Codable {
    case owner
    case admin
    case manager
    case cashier
    
    var isAdminOrManager: Bool {
        return self == .owner || self == .admin || self == .manager
    }
}

struct CurrentUser: Codable {
    var id: String
    var merchantID: String
    var name: String
    var role: StaffRole
    var companyCode: String
    var businessName: String
    var businessType: String
    var phone: String
    var currency: String
}

struct AuthenticatedSession: Codable {
    let token: String
    let currentUser: CurrentUser
    let expiresAt: Date?
}

private enum AppStateError: LocalizedError {
    case sessionPersistenceFailed

    var errorDescription: String? {
        switch self {
        case .sessionPersistenceFailed:
            return "Your account was created, but we couldn't securely save this device session. Please sign in with your phone number and PIN to continue."
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: CurrentUser?
    @Published var isBootstrapping: Bool = true
    @Published var authErrorMessage: String?
    @Published private(set) var pendingOnboardingState: PendingOnboardingState?

    private let sessionStore = SessionStore.shared
    private let onboardingRecoveryStore = OnboardingRecoveryStore.shared
    private let networkService: NetworkServiceProtocol

    init(networkService: NetworkServiceProtocol? = nil) {
        self.networkService = networkService ?? NetworkService.shared

        Task {
            await bootstrap()
        }
    }

    var authToken: String? {
        sessionStore.load()?.token
    }

    var shouldResumeOnboarding: Bool {
        pendingOnboardingState != nil
    }

    func registerBusiness(
        businessName: String,
        ownerName: String,
        businessType: String,
        phone: String,
        pin: String
    ) async throws {
        let normalizedPhone = Self.normalizePhoneNumber(phone)
        let recoveryAttempt = PendingRegistrationAttempt(
            phone: normalizedPhone,
            pin: pin,
            createdAt: Date()
        )

        _ = onboardingRecoveryStore.saveRegistrationAttempt(recoveryAttempt)

        let session: AuthenticatedSession

        do {
            session = try await networkService.register(
                businessName: businessName,
                ownerName: ownerName,
                businessType: businessType,
                phone: normalizedPhone,
                pin: pin
            )
        } catch {
            guard let recoveredSession = await recoverPendingRegistrationSession(using: recoveryAttempt) else {
                throw error
            }

            try startPendingOnboarding(with: recoveredSession)
            return
        }

        try startPendingOnboarding(with: session)
    }

    func completePendingOnboarding() {
        pendingOnboardingState = nil
        onboardingRecoveryStore.clearPendingState()
        onboardingRecoveryStore.clearRegistrationAttempt()
        authErrorMessage = nil
    }

    func loginMerchant(phone: String, pin: String) async throws {
        let normalizedPhone = Self.normalizePhoneNumber(phone)
        let session = try await networkService.loginMerchant(phone: normalizedPhone, pin: pin)
        applyAuthenticatedSession(session)
    }

    func joinBusiness(companyCode: String, pin: String) async throws {
        let session = try await networkService.joinBusiness(companyCode: companyCode, pin: pin)
        applyAuthenticatedSession(session)
    }

    func applyAuthenticatedSession(_ session: AuthenticatedSession) {
        _ = sessionStore.save(session)
        onboardingRecoveryStore.clearRegistrationAttempt()
        persistPendingOnboardingState(nil)
        updateAuthenticatedState(with: session, pendingOnboardingState: nil)
    }

    func logout() {
        SyncEngine.shared.reset()
        sessionStore.clear()
        onboardingRecoveryStore.clearAll()
        pendingOnboardingState = nil
        currentUser = nil
        isAuthenticated = false
        authErrorMessage = nil
    }

    func refreshSession() async {
        guard let storedSession = sessionStore.load() else { return }

        do {
            let refreshedIdentity = try await networkService.getMe(token: storedSession.token)
            let refreshedSession = AuthenticatedSession(
                token: storedSession.token,
                currentUser: CurrentUser(identity: refreshedIdentity),
                expiresAt: storedSession.expiresAt
            )
            applyAuthenticatedSession(
                refreshedSession,
                pendingOnboardingState: pendingOnboardingStateForSession(refreshedSession)
            )
        } catch NetworkError.unauthorized {
            logout()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func bootstrap() async {
        defer { isBootstrapping = false }

        guard let storedSession = sessionStore.load() else {
            pendingOnboardingState = nil
            onboardingRecoveryStore.clearPendingState()
            await recoverInterruptedRegistrationIfNeeded()
            return
        }

        pendingOnboardingState = pendingOnboardingStateForSession(storedSession)
        currentUser = storedSession.currentUser
        isAuthenticated = true
        PersistenceService.shared.ensureLocalIdentity()

        do {
            let refreshedIdentity = try await networkService.getMe(token: storedSession.token)
            let refreshedSession = AuthenticatedSession(
                token: storedSession.token,
                currentUser: CurrentUser(identity: refreshedIdentity),
                expiresAt: storedSession.expiresAt
            )
            applyAuthenticatedSession(
                refreshedSession,
                pendingOnboardingState: pendingOnboardingStateForSession(refreshedSession)
            )
        } catch NetworkError.unauthorized {
            logout()
        } catch {
            // Preserve the cached session if the API is temporarily unavailable.
            authErrorMessage = error.localizedDescription
        }
    }

    private func applyAuthenticatedSession(
        _ session: AuthenticatedSession,
        pendingOnboardingState: PendingOnboardingState?
    ) {
        _ = sessionStore.save(session)
        onboardingRecoveryStore.clearRegistrationAttempt()
        persistPendingOnboardingState(pendingOnboardingState)
        updateAuthenticatedState(with: session, pendingOnboardingState: pendingOnboardingState)
    }

    private func startPendingOnboarding(with session: AuthenticatedSession) throws {
        guard sessionStore.save(session) else {
            throw AppStateError.sessionPersistenceFailed
        }

        let pendingState = PendingOnboardingState(
            merchantID: session.currentUser.merchantID,
            step: .firstProduct,
            createdAt: Date()
        )

        onboardingRecoveryStore.clearRegistrationAttempt()
        persistPendingOnboardingState(pendingState)
        updateAuthenticatedState(with: session, pendingOnboardingState: pendingState)
    }

    private func updateAuthenticatedState(
        with session: AuthenticatedSession,
        pendingOnboardingState: PendingOnboardingState?
    ) {
        self.pendingOnboardingState = pendingOnboardingState
        currentUser = session.currentUser
        isAuthenticated = true
        authErrorMessage = nil
        PersistenceService.shared.ensureLocalIdentity()
        SyncEngine.shared.triggerSync()
    }

    private func persistPendingOnboardingState(_ state: PendingOnboardingState?) {
        if let state {
            _ = onboardingRecoveryStore.savePendingState(state)
        } else {
            onboardingRecoveryStore.clearPendingState()
        }
    }

    private func pendingOnboardingStateForSession(_ session: AuthenticatedSession) -> PendingOnboardingState? {
        guard let pendingState = onboardingRecoveryStore.loadPendingState() else { return nil }

        guard pendingState.merchantID == session.currentUser.merchantID else {
            onboardingRecoveryStore.clearPendingState()
            return nil
        }

        return pendingState
    }

    private func recoverInterruptedRegistrationIfNeeded() async {
        guard let recoveryAttempt = onboardingRecoveryStore.loadRegistrationAttempt() else { return }

        do {
            let recoveredSession = try await networkService.loginMerchant(
                phone: recoveryAttempt.phone,
                pin: recoveryAttempt.pin
            )
            try startPendingOnboarding(with: recoveredSession)
        } catch NetworkError.unauthorized {
            onboardingRecoveryStore.clearRegistrationAttempt()
        } catch {
            // Keep the recovery attempt so the app can retry on the next launch.
        }
    }

    private func recoverPendingRegistrationSession(
        using recoveryAttempt: PendingRegistrationAttempt
    ) async -> AuthenticatedSession? {
        do {
            return try await networkService.loginMerchant(
                phone: recoveryAttempt.phone,
                pin: recoveryAttempt.pin
            )
        } catch {
            return nil
        }
    }
}

extension CurrentUser {
    init(identity: AuthIdentityResponse) {
        self.id = identity.staff.id
        self.merchantID = identity.merchant.id
        self.name = identity.staff.name
        self.role = identity.staff.role
        self.companyCode = identity.merchant.companyCode
        self.businessName = identity.merchant.businessName
        self.businessType = identity.merchant.businessType
        self.phone = identity.staff.phone ?? identity.merchant.phone
        self.currency = identity.merchant.currency ?? "ZMW"
    }
}

private extension AppState {
    static func normalizePhoneNumber(_ rawValue: String) -> String {
        let digits = rawValue.filter(\.isNumber)

        if digits.hasPrefix("260"), digits.count >= 12 {
            return digits
        }

        if digits.hasPrefix("0"), digits.count == 10 {
            return "260\(digits.dropFirst())"
        }

        if digits.count == 9 {
            return "260\(digits)"
        }

        return digits
    }
}

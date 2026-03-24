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

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: CurrentUser?
    @Published var isBootstrapping: Bool = true
    @Published var authErrorMessage: String?

    private let sessionStore = SessionStore.shared
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

    func applyAuthenticatedSession(_ session: AuthenticatedSession) {
        sessionStore.save(session)
        currentUser = session.currentUser
        isAuthenticated = true
        authErrorMessage = nil
        PersistenceService.shared.ensureLocalIdentity()
        SyncEngine.shared.triggerSync()
    }

    func logout() {
        SyncEngine.shared.reset()
        sessionStore.clear()
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
            applyAuthenticatedSession(refreshedSession)
        } catch NetworkError.unauthorized {
            logout()
        } catch {
            authErrorMessage = error.localizedDescription
        }
    }

    private func bootstrap() async {
        defer { isBootstrapping = false }

        guard let storedSession = sessionStore.load() else { return }

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
            applyAuthenticatedSession(refreshedSession)
        } catch NetworkError.unauthorized {
            logout()
        } catch {
            // Preserve the cached session if the API is temporarily unavailable.
            authErrorMessage = error.localizedDescription
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

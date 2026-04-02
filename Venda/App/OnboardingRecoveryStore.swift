import Foundation

enum PendingOnboardingStep: String, Codable {
    case firstProduct
}

struct PendingOnboardingState: Codable {
    let merchantID: String
    let step: PendingOnboardingStep
    let createdAt: Date
}

struct PendingRegistrationAttempt: Codable {
    let phone: String
    let pin: String
    let createdAt: Date
}

final class OnboardingRecoveryStore {
    static let shared = OnboardingRecoveryStore()

    private static let registrationAttemptLifetime: TimeInterval = 60 * 60 * 24 * 7

    private let keychain = SecureKeychain.shared
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let registrationAttemptKey = "venda.onboarding.registration-attempt"
    private let pendingStateKey = "venda.onboarding.pending-state"

    private init() {}

    @discardableResult
    func saveRegistrationAttempt(_ attempt: PendingRegistrationAttempt) -> Bool {
        guard let data = try? encoder.encode(attempt) else { return false }
        return keychain.set(data, for: registrationAttemptKey)
    }

    func loadRegistrationAttempt() -> PendingRegistrationAttempt? {
        guard let data = keychain.data(for: registrationAttemptKey) else { return nil }
        guard let attempt = try? decoder.decode(PendingRegistrationAttempt.self, from: data) else {
            clearRegistrationAttempt()
            return nil
        }

        if Date().timeIntervalSince(attempt.createdAt) > Self.registrationAttemptLifetime {
            clearRegistrationAttempt()
            return nil
        }

        return attempt
    }

    func clearRegistrationAttempt() {
        keychain.remove(registrationAttemptKey)
    }

    @discardableResult
    func savePendingState(_ state: PendingOnboardingState) -> Bool {
        guard let data = try? encoder.encode(state) else { return false }
        defaults.set(data, forKey: pendingStateKey)
        return true
    }

    func loadPendingState() -> PendingOnboardingState? {
        guard let data = defaults.data(forKey: pendingStateKey) else { return nil }
        guard let state = try? decoder.decode(PendingOnboardingState.self, from: data) else {
            clearPendingState()
            return nil
        }

        return state
    }

    func clearPendingState() {
        defaults.removeObject(forKey: pendingStateKey)
    }

    func clearAll() {
        clearRegistrationAttempt()
        clearPendingState()
    }
}

import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let keychain = SecureKeychain.shared
    private let defaults = UserDefaults.standard
    private let storageKey = "venda.auth.session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {}

    @discardableResult
    func save(_ session: AuthenticatedSession) -> Bool {
        guard let data = try? encoder.encode(session) else { return false }
        guard keychain.set(data, for: storageKey) else { return false }
        defaults.removeObject(forKey: storageKey)
        return true
    }

    func load() -> AuthenticatedSession? {
        guard let data = keychain.data(for: storageKey) ?? migrateLegacySession() else { return nil }
        guard let session = try? decoder.decode(AuthenticatedSession.self, from: data) else {
            clear()
            return nil
        }

        if let expiresAt = session.expiresAt, expiresAt <= Date() {
            clear()
            return nil
        }

        return session
    }

    func clear() {
        keychain.remove(storageKey)
        defaults.removeObject(forKey: storageKey)
    }

    private func migrateLegacySession() -> Data? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }

        if keychain.set(data, for: storageKey) {
            defaults.removeObject(forKey: storageKey)
        }

        return data
    }
}

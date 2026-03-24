import Foundation

final class SessionStore {
    static let shared = SessionStore()

    private let defaults = UserDefaults.standard
    private let storageKey = "venda.auth.session"

    private init() {}

    func save(_ session: AuthenticatedSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        defaults.set(data, forKey: storageKey)
    }

    func load() -> AuthenticatedSession? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(AuthenticatedSession.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: storageKey)
    }
}

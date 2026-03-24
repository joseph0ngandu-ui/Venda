import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    
    // In a real app, you would persist this in Keychain/UserDefaults
    // and check upon app launch to set initial state.
    
    func logout() {
        isAuthenticated = false
    }
}

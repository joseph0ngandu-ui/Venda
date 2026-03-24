import Foundation
import Combine

enum StaffRole: String, Codable {
    case admin
    case manager
    case cashier
    
    var isAdminOrManager: Bool {
        return self == .admin || self == .manager
    }
}

struct CurrentUser: Codable {
    var id: UUID
    var name: String
    var role: StaffRole
    var companyCode: String
}

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: CurrentUser?
    @Published var hasCompletedOnboarding: Bool = false
    
    // In a real app, you would persist this in Keychain/UserDefaults
    // and check upon app launch to set initial state.
    
    func login(user: CurrentUser) {
        self.currentUser = user
        self.isAuthenticated = true
    }
    
    func logout() {
        self.currentUser = nil
        self.isAuthenticated = false
    }
}

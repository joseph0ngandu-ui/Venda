import Foundation
import Combine

@MainActor
final class AdminPanelViewModel: ObservableObject {
    @Published var staff: [StaffProfileResponse] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let appState: AppState
    private let network: NetworkServiceProtocol

    init(appState: AppState, network: NetworkServiceProtocol? = nil) {
        self.appState = appState
        self.network = network ?? NetworkService.shared
    }

    func loadStaff() async {
        guard let token = appState.authToken else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            staff = try await network.fetchStaff(token: token)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createStaff(name: String, role: StaffRole, pin: String) async {
        guard let token = appState.authToken else { return }

        do {
            _ = try await network.createStaff(token: token, name: name, role: role, pin: pin)
            await loadStaff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateStaff(member: StaffProfileResponse, name: String? = nil, role: StaffRole? = nil, pin: String? = nil, isActive: Bool? = nil) async {
        guard let token = appState.authToken else { return }

        do {
            _ = try await network.updateStaff(
                token: token,
                staffID: member.id,
                name: name,
                role: role,
                pin: pin,
                isActive: isActive
            )
            await loadStaff()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

import SwiftUI
import Combine
import CoreData

@MainActor
final class MoneyViewModel: ObservableObject {
    @Published var matchedMoMo: Decimal = 0
    @Published var pendingMoMo: Decimal = 0
    @Published var unmatchedMoMo: Decimal = 0
    @Published var momoTransactions: [MoMoTransactionSummary] = []
    
    @Published var creditEntries: [CreditEntrySummary] = []
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceService? = nil) {
        self.persistence = persistence ?? PersistenceService.shared
        refreshData()
        observeChanges()
    }
    
    func refreshData() {
        let snapshot = persistence.fetchMoneyState()
        matchedMoMo = snapshot.matchedMoMo
        pendingMoMo = snapshot.pendingMoMo
        unmatchedMoMo = snapshot.unmatchedMoMo
        momoTransactions = snapshot.momoTransactions
        creditEntries = snapshot.creditEntries
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }
}

struct MoMoTransactionSummary: Identifiable {
    let id: UUID
    let reference: String
    let senderPhone: String
    let amount: Decimal
    let status: String
    let timestamp: Date
}

struct CreditEntrySummary: Identifiable {
    let id: UUID
    let customerName: String
    let amountOwed: Decimal
    let repaidAmount: Decimal
    let lastTransaction: Date
}

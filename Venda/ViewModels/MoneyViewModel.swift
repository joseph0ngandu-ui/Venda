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
    @Published var availableSales: [SaleSummary] = []
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceService? = nil) {
        self.persistence = persistence ?? PersistenceService.shared
        refreshData()
        observeChanges()
    }

    var totalMoMoVolume: Decimal {
        matchedMoMo + pendingMoMo + unmatchedMoMo
    }

    var outstandingCredit: Decimal {
        creditEntries.reduce(0) { $0 + $1.amountOwed }
    }

    var overdueCredit: Decimal {
        creditEntries.filter(\.isOverdue).reduce(0) { $0 + $1.amountOwed }
    }

    var overdueCreditCount: Int {
        creditEntries.filter(\.isOverdue).count
    }

    var openCreditCustomers: Int {
        creditEntries.filter { $0.amountOwed > 0 }.count
    }
    
    func refreshData() {
        let snapshot = persistence.fetchMoneyState()
        matchedMoMo = snapshot.matchedMoMo
        pendingMoMo = snapshot.pendingMoMo
        unmatchedMoMo = snapshot.unmatchedMoMo
        momoTransactions = snapshot.momoTransactions
        creditEntries = snapshot.creditEntries
        availableSales = snapshot.availableSales
    }

    func addMoMo(reference: String, senderPhone: String, amount: Decimal) {
        persistence.addMoMoTransaction(reference: reference, senderPhone: senderPhone, amount: amount)
        refreshData()
    }

    func matchMoMo(id: UUID, saleID: UUID?) {
        persistence.matchMoMoTransaction(id: id, saleID: saleID)
        refreshData()
    }

    func updateMoMoStatus(id: UUID, status: String) {
        persistence.updateMoMoTransactionStatus(id: id, status: status)
        refreshData()
    }

    func addCredit(customerName: String, customerPhone: String?, amount: Decimal, dueDate: Date?) {
        persistence.createCreditEntry(customerName: customerName, customerPhone: customerPhone, amount: amount, dueDate: dueDate)
        refreshData()
    }

    func repayCredit(id: UUID, amount: Decimal) {
        persistence.recordCreditRepayment(id: id, amount: amount)
        refreshData()
    }

    func settleCredit(id: UUID) {
        if let entry = creditEntries.first(where: { $0.id == id }) {
            persistence.recordCreditRepayment(id: id, amount: entry.amountOwed)
            refreshData()
        }
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
    let customerPhone: String?
    let amountOwed: Decimal
    let originalAmount: Decimal
    let repaidAmount: Decimal
    let dueDate: Date?
    let status: String
    let lastTransaction: Date
    let isOverdue: Bool
}

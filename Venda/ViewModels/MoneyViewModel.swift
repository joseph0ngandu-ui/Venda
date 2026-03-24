import SwiftUI
import Combine

@MainActor
final class MoneyViewModel: ObservableObject {
    @Published var matchedMoMo: Decimal = 0
    @Published var pendingMoMo: Decimal = 0
    @Published var unmatchedMoMo: Decimal = 0
    @Published var momoTransactions: [MoMoTransactionSummary] = []
    
    @Published var creditEntries: [CreditEntrySummary] = []
    
    func refreshData() {
        // Will fetch from CoreData in the next step
        // Leaving arrays empty removes hardcoded mock data from UI
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

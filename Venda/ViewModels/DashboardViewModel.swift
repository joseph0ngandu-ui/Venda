import SwiftUI
import Combine
import CoreData

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var totalRevenue: Decimal = 0
    @Published var salesCount: Int = 0
    @Published var recentSales: [SaleSummary] = []
    @Published var paymentBreakdown: [(method: String, amount: Decimal)] = []
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceService? = nil) {
        self.persistence = persistence ?? PersistenceService.shared
        refresh()
        observeChanges()
    }

    func updateMetrics(from sales: [SaleSummary]) {
        totalRevenue = sales.reduce(0) { $0 + $1.amount }
        salesCount = sales.count
        recentSales = Array(sales.prefix(5))
        
        var breakdown: [String: Decimal] = [:]
        for sale in sales {
            breakdown[sale.paymentMethod, default: 0] += sale.amount
        }
        paymentBreakdown = breakdown.map { (method: $0.key, amount: $0.value) }.sorted { $0.amount > $1.amount }
    }

    func refresh() {
        updateMetrics(from: persistence.fetchSales())
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }
}

struct SaleSummary: Identifiable {
    let id: UUID
    let reference: String
    let amount: Decimal
    let paymentMethod: String
    let staffName: String
    let timestamp: Date
}

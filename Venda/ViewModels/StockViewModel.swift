import SwiftUI
import Combine
import CoreData

@MainActor
final class StockViewModel: ObservableObject {
    @Published var products: [ProductModel] = []
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(persistence: PersistenceService? = nil) {
        self.persistence = persistence ?? PersistenceService.shared
        reload()
        observeChanges()
    }

    func addProduct(_ product: ProductModel) {
        persistence.saveProduct(product)
        reload()
    }

    func updateProduct(_ product: ProductModel) {
        persistence.saveProduct(product)
        reload()
    }

    func deleteProduct(_ id: UUID) {
        persistence.deleteProduct(id)
        reload()
    }

    private func reload() {
        products = persistence.fetchProducts()
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reload()
            }
            .store(in: &cancellables)
    }
}

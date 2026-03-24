import SwiftUI
import Combine

@MainActor
final class StockViewModel: ObservableObject {
    @Published var products: [ProductModel] = []

    func addProduct(_ product: ProductModel) {
        products.append(product)
    }

    func updateProduct(_ product: ProductModel) {
        if let index = products.firstIndex(where: { $0.id == product.id }) {
            products[index] = product
        }
    }

    func deleteProduct(_ id: UUID) {
        products.removeAll { $0.id == id }
    }
}

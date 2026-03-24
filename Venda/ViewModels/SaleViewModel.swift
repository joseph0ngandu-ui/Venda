import SwiftUI
import Combine

@MainActor
final class SaleViewModel: ObservableObject {
    @Published var cartItems: [CartItem] = []
    @Published var selectedPaymentMethod: String = "Cash"
    @Published var currentSaleReference: String = ""

    private var pricingService = PricingService()

    func addToCart(product: ProductModel, quantity: Decimal = 1, finalPrice: Decimal) {
        let item = CartItem(
            id: UUID(),
            product: product,
            quantity: quantity,
            finalPrice: finalPrice
        )
        cartItems.append(item)
    }

    func removeFromCart(id: UUID) {
        cartItems.removeAll { $0.id == id }
    }

    func cartTotal() -> Decimal {
        cartItems.reduce(0) { $0 + ($1.finalPrice * $1.quantity) }
    }

    func completeSale() {
        let reference = "VND-\(String(Int.random(in: 1...9999)).padded(to: 4))"
        currentSaleReference = reference
        cartItems.removeAll()
    }

    func validatePrice(_ price: Decimal, for product: ProductModel) -> PriceValidationResult {
        pricingService.validatePrice(price, for: product)
    }
}

struct CartItem: Identifiable {
    let id: UUID
    let product: ProductModel
    let quantity: Decimal
    let finalPrice: Decimal
}

extension String {
    func padded(to length: Int) -> String {
        let toPad = length - self.count
        guard toPad > 0 else { return self }
        return String(repeating: "0", count: toPad) + self
    }
}

import Foundation

struct ProductModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var pricingType: PricingType
    var suggestedPrice: Decimal?
    var minPrice: Decimal?
    var maxPrice: Decimal?
    var stockQuantity: Int
    var lowStockThreshold: Int
    var trackStock: Bool
    var isService: Bool
    var isActive: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        pricingType: PricingType,
        suggestedPrice: Decimal? = nil,
        minPrice: Decimal? = nil,
        maxPrice: Decimal? = nil,
        stockQuantity: Int = 0,
        lowStockThreshold: Int = 5,
        trackStock: Bool = true,
        isService: Bool = false,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pricingType = pricingType
        self.suggestedPrice = suggestedPrice
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.stockQuantity = stockQuantity
        self.lowStockThreshold = lowStockThreshold
        self.trackStock = trackStock
        self.isService = isService
        self.isActive = isActive
    }
}

import Foundation

struct ProductModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var category: String
    var pricingType: PricingType
    var suggestedPrice: Decimal?
    var minPrice: Decimal?
    var maxPrice: Decimal?
    var isService: Bool

    init(
        id: UUID = UUID(),
        name: String,
        category: String,
        pricingType: PricingType,
        suggestedPrice: Decimal? = nil,
        minPrice: Decimal? = nil,
        maxPrice: Decimal? = nil,
        isService: Bool = false
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.pricingType = pricingType
        self.suggestedPrice = suggestedPrice
        self.minPrice = minPrice
        self.maxPrice = maxPrice
        self.isService = isService
    }
}

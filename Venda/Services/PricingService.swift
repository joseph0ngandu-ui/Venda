import Foundation

protocol PricingServiceProtocol {
    func validatePrice(_ enteredPrice: Decimal, for product: ProductModel) -> PriceValidationResult
}

struct PricingService: PricingServiceProtocol {
    func validatePrice(_ enteredPrice: Decimal, for product: ProductModel) -> PriceValidationResult {
        switch product.pricingType {
        case .fixed:
            guard let suggested = product.suggestedPrice else { return .valid }
            return enteredPrice == suggested ? .valid : .blocked

        case .flexible:
            guard let suggested = product.suggestedPrice, suggested != 0 else { return .valid }
            let diff = (enteredPrice - suggested).magnitude
            let deviation = (diff as NSDecimalNumber).doubleValue / (suggested as NSDecimalNumber).doubleValue
            return deviation > 0.20 ? .warningLogged : .valid

        case .range:
            guard let minPrice = product.minPrice, let maxPrice = product.maxPrice else { return .valid }
            if enteredPrice < minPrice || enteredPrice > maxPrice {
                return .outsideRange
            }
            return .valid

        case .open, .service:
            return .valid
        }
    }
}

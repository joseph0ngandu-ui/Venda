import Foundation

enum PricingType: String, CaseIterable, Codable {
    case fixed
    case flexible
    case range
    case open
    case service
}

enum PriceValidationResult {
    case valid
    case blocked
    case warningLogged
    case outsideRange
}

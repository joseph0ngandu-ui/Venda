import Foundation

extension Decimal {
    private static let zmwFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_ZM")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "K "
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    func asZMW() -> String {
        let number = self as NSDecimalNumber
        return Decimal.zmwFormatter.string(from: number) ?? "K 0.00"
    }
}

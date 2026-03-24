import Foundation

extension Date {
    private static let vendaTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    func asVendaTime() -> String {
        Date.vendaTimeFormatter.string(from: self)
    }
}

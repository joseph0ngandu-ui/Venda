import Foundation
import Combine
import CoreData

enum ReportTimeframe: String, CaseIterable {
    case week
    case month
    case year

    var title: String {
        switch self {
        case .week: return "This Week"
        case .month: return "This Month"
        case .year: return "This Year"
        }
    }

    var comparisonLabel: String {
        switch self {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
    }

    func dateInterval(containing date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: date) ?? DateInterval(start: date, end: date)
        case .month:
            return calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, end: date)
        case .year:
            return calendar.dateInterval(of: .year, for: date) ?? DateInterval(start: date, end: date)
        }
    }

    func previousDateInterval(from interval: DateInterval, calendar: Calendar) -> DateInterval {
        switch self {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: interval.start) ?? interval.start
            return DateInterval(start: start, end: interval.start)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: interval.start) ?? interval.start
            return DateInterval(start: start, end: interval.start)
        case .year:
            let start = calendar.date(byAdding: .year, value: -1, to: interval.start) ?? interval.start
            return DateInterval(start: start, end: interval.start)
        }
    }

    func makeTrendPoints(from sales: [Sale], calendar: Calendar) -> [ChartDataPoint] {
        let interval = dateInterval(containing: Date(), calendar: calendar)

        switch self {
        case .week:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEEE"
            return (0..<7).compactMap { index in
                guard let start = calendar.date(byAdding: .day, value: index, to: interval.start),
                      let end = calendar.date(byAdding: .day, value: 1, to: start)
                else {
                    return nil
                }

                let total = sales
                    .filter { sale in
                        guard let createdAt = sale.createdAt else { return false }
                        return createdAt >= start && createdAt < end
                    }
                    .reduce(0) { $0 + decimal($1.totalAmount) }

                return ChartDataPoint(label: formatter.string(from: start), value: total)
            }

        case .month:
            var points: [ChartDataPoint] = []
            var bucketStart = interval.start
            var weekIndex = 1

            while bucketStart < interval.end {
                let bucketEnd = min(calendar.date(byAdding: .day, value: 7, to: bucketStart) ?? interval.end, interval.end)
                let total = sales
                    .filter { sale in
                        guard let createdAt = sale.createdAt else { return false }
                        return createdAt >= bucketStart && createdAt < bucketEnd
                    }
                    .reduce(0) { $0 + decimal($1.totalAmount) }

                points.append(ChartDataPoint(label: "W\(weekIndex)", value: total))
                weekIndex += 1
                bucketStart = bucketEnd
            }

            return points

        case .year:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM"
            let year = calendar.component(.year, from: interval.start)

            return (1...12).compactMap { month in
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = 1

                guard let start = calendar.date(from: components),
                      let end = calendar.date(byAdding: .month, value: 1, to: start)
                else {
                    return nil
                }

                let total = sales
                    .filter { sale in
                        guard let createdAt = sale.createdAt else { return false }
                        return createdAt >= start && createdAt < end
                    }
                    .reduce(0) { $0 + decimal($1.totalAmount) }

                return ChartDataPoint(label: formatter.string(from: start), value: total)
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Decimal
}

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var selectedTimeframe: ReportTimeframe = .week
    @Published var totalRevenue: Decimal = 0
    @Published var salesCount: Int = 0
    @Published var averageSale: Decimal = 0
    @Published var paymentBreakdown: [ReportPaymentBreakdown] = []
    @Published var topProducts: [ReportTopProductRowModel] = []
    @Published var trend: [ChartDataPoint] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var usingOfflineSnapshot = false

    private let network: NetworkServiceProtocol
    private let persistence: PersistenceService
    private var cancellables = Set<AnyCancellable>()

    init(
        network: NetworkServiceProtocol? = nil,
        persistence: PersistenceService? = nil
    ) {
        self.network = network ?? NetworkService.shared
        self.persistence = persistence ?? .shared
        observeChanges()
    }

    var maxTrendValue: Decimal {
        trend.map(\.value).max() ?? 1
    }

    var trendSummary: String {
        let previousRevenue = persistence.fetchLocalReportsSnapshot(timeframe: selectedTimeframe).previousRevenue

        guard previousRevenue > 0 else {
            return totalRevenue > 0 ? "First \(selectedTimeframe.rawValue) with recorded sales" : "No sales recorded for this period yet"
        }

        let change = ((NSDecimalNumber(decimal: totalRevenue).doubleValue - NSDecimalNumber(decimal: previousRevenue).doubleValue) / NSDecimalNumber(decimal: previousRevenue).doubleValue) * 100

        if change == 0 {
            return "Flat versus \(selectedTimeframe.comparisonLabel)"
        }

        let direction = change > 0 ? "+" : ""
        return String(format: "%@%.1f%% versus %@", direction, change, selectedTimeframe.comparisonLabel)
    }

    func load(token: String?) async {
        guard let token else {
            applyLocalSnapshot()
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await network.fetchReportsSummary(token: token, timeframe: selectedTimeframe.rawValue)
            totalRevenue = response.summary.totalRevenue
            salesCount = response.summary.salesCount
            averageSale = response.summary.averageSale
            paymentBreakdown = response.paymentBreakdown
            trend = response.trend.map { ChartDataPoint(label: $0.label, value: $0.amount) }
            topProducts = response.topProducts.map {
                ReportTopProductRowModel(name: $0.name, sales: Int(truncating: $0.unitsSold as NSNumber), revenue: $0.revenue)
            }
            errorMessage = nil
            usingOfflineSnapshot = false
        } catch {
            errorMessage = error.localizedDescription
            applyLocalSnapshot()
        }
    }

    private func applyLocalSnapshot() {
        let snapshot = persistence.fetchLocalReportsSnapshot(timeframe: selectedTimeframe)
        totalRevenue = snapshot.totalRevenue
        salesCount = snapshot.salesCount
        averageSale = snapshot.averageSale
        paymentBreakdown = snapshot.paymentBreakdown
        trend = snapshot.trend
        topProducts = snapshot.topProducts
        usingOfflineSnapshot = true
    }

    private func observeChanges() {
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.usingOfflineSnapshot else { return }
                self.applyLocalSnapshot()
            }
            .store(in: &cancellables)
    }
}

struct ReportTopProductRowModel: Identifiable {
    let id = UUID()
    let name: String
    let sales: Int
    let revenue: Decimal
}

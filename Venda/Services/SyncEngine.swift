import Foundation
import CoreData
import Network
import Combine

class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isSyncing = false
    @Published var isOnline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SyncMonitor")
    private var syncTask: Task<Void, Never>?

    private let sessionStore = SessionStore.shared
    private let persistence = PersistenceService.shared
    private let syncPushURL = NetworkService.shared.apiBaseURL.appendingPathComponent("sync/push")
    private let syncPullURL = NetworkService.shared.apiBaseURL.appendingPathComponent("sync/pull")
    private let defaults = UserDefaults.standard
    private let lastSyncKey = "venda.last.successful.sync"
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private init() {}

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied

            DispatchQueue.main.async {
                self?.isOnline = online
                if online {
                    self?.triggerSync()
                }
            }
        }
        monitor.start(queue: queue)
    }

    func triggerSync() {
        guard isOnline, !isSyncing else { return }

        syncTask?.cancel()
        syncTask = Task {
            await performSync()
        }
    }

    private func performSync() async {
        DispatchQueue.main.async { self.isSyncing = true }
        defer { DispatchQueue.main.async { self.isSyncing = false } }

        guard let token = sessionStore.load()?.token else {
            return
        }

        do {
            try await performSyncPull(token: token)
            try await performSyncPush(token: token)
            defaults.set(Date(), forKey: lastSyncKey)
        } catch {
            print("Sync failed: \(error.localizedDescription)")
        }
    }

    private func performSyncPush(token: String) async throws {
        let context = CoreDataManager.shared.backgroundContext()
        let unsyncedSales = try fetchUnsynced(entity: Sale.self, in: context)
        let unsyncedProducts = try fetchUnsynced(entity: Product.self, in: context)

        if unsyncedSales.isEmpty && unsyncedProducts.isEmpty {
            return
        }

        let unsyncedLineItems = unsyncedSales
            .compactMap { $0.lineItems as? Set<SaleLineItem> }
            .flatMap { $0 }

        var payload: [String: Any] = [:]

        if !unsyncedProducts.isEmpty {
            payload["products"] = unsyncedProducts.map { product in
                [
                    "id": product.id?.uuidString ?? UUID().uuidString,
                    "name": product.name ?? "",
                    "category": product.category ?? "",
                    "pricing_type": product.pricingType ?? "fixed",
                    "suggested_price": decimal(product.suggestedPrice),
                    "min_price": decimal(product.minPrice),
                    "max_price": decimal(product.maxPrice),
                    "stock_quantity": Int(product.stockQuantity),
                    "low_stock_threshold": Int(product.lowStockThreshold),
                    "track_stock": product.trackStock,
                    "is_service": product.isService,
                    "is_active": product.isActive,
                    "created_at": isoString(from: product.createdAt),
                    "updated_at": isoString(from: product.syncedAt ?? product.createdAt ?? Date())
                ]
            }
        }

        if !unsyncedSales.isEmpty {
            payload["sales"] = unsyncedSales.map { sale in
                [
                    "id": sale.id?.uuidString ?? UUID().uuidString,
                    "staff_id": sale.staff?.id?.uuidString as Any,
                    "reference": sale.reference ?? "",
                    "total_amount": decimal(sale.totalAmount),
                    "payment_method": sale.paymentMethod ?? "Cash",
                    "customer_phone": sale.customerPhone as Any,
                    "status": sale.status ?? "completed",
                    "notes": sale.notes as Any,
                    "created_at": isoString(from: sale.createdAt),
                    "updated_at": isoString(from: sale.syncedAt ?? sale.createdAt ?? Date())
                ]
            }
        }

        if !unsyncedLineItems.isEmpty {
            payload["sale_line_items"] = unsyncedLineItems.map { item in
                [
                    "id": item.id?.uuidString ?? UUID().uuidString,
                    "sale_id": item.sale?.id?.uuidString ?? "",
                    "product_id": item.product?.id?.uuidString as Any,
                    "quantity": decimal(item.quantity),
                    "unit_price": decimal(item.unitPrice),
                    "original_price": decimal(item.originalPrice),
                    "final_price": decimal(item.finalPrice),
                    "discount_amount": decimal(item.discountAmount),
                    "discount_reason": item.discountReason as Any,
                    "price_override_by": item.priceOverrideBy as Any,
                    "created_at": isoString(from: item.createdAt),
                    "updated_at": isoString(from: item.syncedAt ?? item.createdAt ?? Date())
                ]
            }
        }

        var request = URLRequest(url: syncPushURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            let now = Date()
            for object in unsyncedSales + unsyncedProducts {
                object.setValue(now, forKey: "syncedAt")
            }
            for lineItem in unsyncedLineItems {
                lineItem.syncedAt = now
            }
            try context.save()
        } else if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
            throw NetworkError.unauthorized
        }
    }

    private func performSyncPull(token: String) async throws {
        let lastSyncDate = defaults.object(forKey: lastSyncKey) as? Date ?? Date(timeIntervalSince1970: 0)
        var components = URLComponents(url: syncPullURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "updated_after", value: isoString(from: lastSyncDate))]

        guard let url = components?.url else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response type")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let payload = try decoder.decode(PullSyncEnvelope.self, from: data)
        persistence.applySyncPayload(payload.data)
    }

    private func fetchUnsynced<T: NSManagedObject>(entity: T.Type, in context: NSManagedObjectContext) throws -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.predicate = NSPredicate(format: "syncedAt == nil")
        return try context.fetch(fetchRequest)
    }

    private func isoString(from date: Date?) -> String {
        guard let date else { return "" }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

struct PullSyncEnvelope: Decodable {
    let timestamp: String
    let data: PullSyncPayload
}

struct PullSyncPayload: Decodable {
    let products: [SyncedProduct]
    let sales: [SyncedSale]
    let saleLineItems: [SyncedSaleLineItem]
    let staff: [SyncedStaff]
    let momoTransactions: [SyncedMoMoTransaction]
    let creditEntries: [SyncedCreditEntry]
}

struct SyncedProduct: Decodable {
    let id: UUID
    let name: String
    let category: String?
    let pricingType: String
    let suggestedPrice: Decimal?
    let minPrice: Decimal?
    let maxPrice: Decimal?
    let stockQuantity: Int?
    let lowStockThreshold: Int?
    let trackStock: Bool?
    let isService: Bool?
    let isActive: Bool?
    let createdAt: String?
}

struct SyncedSale: Decodable {
    let id: UUID
    let staffID: UUID?
    let reference: String
    let totalAmount: Decimal
    let paymentMethod: String
    let customerPhone: String?
    let status: String?
    let notes: String?
    let createdAt: String?
}

struct SyncedSaleLineItem: Decodable {
    let id: UUID
    let saleID: UUID
    let productID: UUID?
    let quantity: Decimal
    let unitPrice: Decimal
    let originalPrice: Decimal?
    let finalPrice: Decimal
    let discountAmount: Decimal?
    let discountReason: String?
    let priceOverrideBy: String?
    let createdAt: String?
}

struct SyncedStaff: Decodable {
    let id: UUID
    let name: String
    let role: String
    let isActive: Bool
    let createdAt: String?
}

struct SyncedMoMoTransaction: Decodable {
    let id: UUID
    let saleID: UUID?
    let transactionRef: String
    let senderPhone: String
    let amount: Decimal
    let status: String?
    let receivedAt: String?
    let createdAt: String?
}

struct SyncedCreditEntry: Decodable {
    let id: UUID
    let saleID: UUID?
    let customerName: String
    let customerPhone: String?
    let amount: Decimal
    let amountRepaid: Decimal?
    let dueDate: String?
    let status: String?
    let createdAt: String?
}

import Combine
import CoreData
import Foundation
import Network

class SyncEngine: ObservableObject {
    static let shared = SyncEngine()

    @Published var isSyncing = false
    @Published var isOnline = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "SyncMonitor")
    private var hasStartedMonitoring = false
    private var syncTask: Task<Void, Never>?

    private let sessionStore = SessionStore.shared
    private let persistence = PersistenceService.shared
    private let defaults = UserDefaults.standard
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private let formatter = ISO8601DateFormatter()

    private init() {}

    func startMonitoring() {
        guard !hasStartedMonitoring else { return }
        hasStartedMonitoring = true

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

    func reset() {
        syncTask?.cancel()
        syncTask = nil

        DispatchQueue.main.async {
            self.isSyncing = false
        }
    }

    private func performSync() async {
        guard let session = sessionStore.load() else { return }

        await MainActor.run {
            isSyncing = true
        }
        defer {
            Task { @MainActor in
                self.isSyncing = false
            }
        }

        do {
            try await performSyncPull(token: session.token, merchantID: session.currentUser.merchantID)
            guard !Task.isCancelled else { return }

            try await performSyncPush(token: session.token, merchantID: session.currentUser.merchantID)
            defaults.set(Date(), forKey: lastSyncKey(for: session.currentUser.merchantID))
        } catch {
            print("Sync failed: \(error.localizedDescription)")
        }
    }

    private func performSyncPush(token: String, merchantID: String) async throws {
        let context = CoreDataManager.shared.backgroundContext()
        var payload: [String: Any] = [:]
        var syncedObjectIDs: [NSManagedObjectID] = []
        var syncedLineItemIDs: [NSManagedObjectID] = []

        var fetchError: Error?
        context.performAndWait {
            do {
                let unsyncedProducts = try fetchUnsynced(entity: Product.self, merchantID: merchantID, in: context)
                let unsyncedSales = try fetchUnsynced(entity: Sale.self, merchantID: merchantID, in: context)
                let unsyncedMoMo = try fetchUnsynced(entity: MoMoTransaction.self, merchantID: merchantID, in: context)
                let unsyncedCredit = try fetchUnsynced(entity: CreditEntry.self, merchantID: merchantID, in: context)

                if unsyncedProducts.isEmpty && unsyncedSales.isEmpty && unsyncedMoMo.isEmpty && unsyncedCredit.isEmpty {
                    return
                }

                let unsyncedLineItems = unsyncedSales
                    .compactMap { $0.lineItems as? Set<SaleLineItem> }
                    .flatMap { $0 }
                    .filter { $0.syncedAt == nil }

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

                if !unsyncedMoMo.isEmpty {
                    payload["momo_transactions"] = unsyncedMoMo.map { momo in
                        [
                            "id": momo.id?.uuidString ?? UUID().uuidString,
                            "sale_id": momo.sale?.id?.uuidString as Any,
                            "transaction_ref": momo.transactionRef ?? "",
                            "sender_phone": momo.senderPhone ?? "",
                            "amount": decimal(momo.amount),
                            "status": momo.status ?? "unmatched",
                            "received_at": isoString(from: momo.receivedAt),
                            "created_at": isoString(from: momo.createdAt),
                            "updated_at": isoString(from: momo.syncedAt ?? momo.createdAt ?? Date())
                        ]
                    }
                }

                if !unsyncedCredit.isEmpty {
                    payload["credit_entries"] = unsyncedCredit.map { credit in
                        [
                            "id": credit.id?.uuidString ?? UUID().uuidString,
                            "sale_id": credit.sale?.id?.uuidString as Any,
                            "customer_name": credit.customerName ?? "",
                            "customer_phone": credit.customerPhone as Any,
                            "amount": decimal(credit.amount),
                            "amount_repaid": decimal(credit.amountRepaid),
                            "due_date": isoString(from: credit.dueDate),
                            "status": credit.status ?? "outstanding",
                            "created_at": isoString(from: credit.createdAt),
                            "updated_at": isoString(from: credit.syncedAt ?? credit.createdAt ?? Date())
                        ]
                    }
                }

                syncedObjectIDs =
                    unsyncedProducts.map(\.objectID) +
                    unsyncedSales.map(\.objectID) +
                    unsyncedMoMo.map(\.objectID) +
                    unsyncedCredit.map(\.objectID)
                syncedLineItemIDs = unsyncedLineItems.map(\.objectID)
            } catch {
                fetchError = error
            }
        }

        if let fetchError {
            throw fetchError
        }

        guard !payload.isEmpty else {
            return
        }

        var request = URLRequest(url: syncPushURL())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.serverError("Invalid response type")
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw NetworkError.unauthorized
        }

        guard httpResponse.statusCode == 200 else {
            throw NetworkError.serverError("HTTP \(httpResponse.statusCode)")
        }

        let now = Date()
        var saveError: Error?
        context.performAndWait {
            do {
                for objectID in syncedObjectIDs {
                    let object = context.object(with: objectID)
                    object.setValue(now, forKey: "syncedAt")
                }

                for objectID in syncedLineItemIDs {
                    if let lineItem = try? context.existingObject(with: objectID) as? SaleLineItem {
                        lineItem.syncedAt = now
                    }
                }

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                saveError = error
            }
        }

        if let saveError {
            throw saveError
        }
    }

    private func performSyncPull(token: String, merchantID: String) async throws {
        let lastSyncDate = defaults.object(forKey: lastSyncKey(for: merchantID)) as? Date ?? Date(timeIntervalSince1970: 0)
        var components = URLComponents(url: syncPullURL(), resolvingAgainstBaseURL: false)
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

    private func fetchUnsynced<T: NSManagedObject>(
        entity: T.Type,
        merchantID: String,
        in context: NSManagedObjectContext
    ) throws -> [T] {
        let request = NSFetchRequest<T>(entityName: String(describing: T.self))
        let merchantUUID = UUID(uuidString: merchantID) ?? UUID()
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "syncedAt == nil"),
            NSPredicate(format: "merchant.id == %@", merchantUUID as CVarArg)
        ])
        return try context.fetch(request)
    }

    private func lastSyncKey(for merchantID: String) -> String {
        "venda.last.successful.sync.\(merchantID)"
    }

    private func syncPushURL() -> URL {
        NetworkService.shared.apiBaseURL.appendingPathComponent("sync/push")
    }

    private func syncPullURL() -> URL {
        NetworkService.shared.apiBaseURL.appendingPathComponent("sync/pull")
    }

    private func isoString(from date: Date?) -> String {
        guard let date else { return "" }
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

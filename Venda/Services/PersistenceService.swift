import Foundation
import CoreData

final class PersistenceService {
    static let shared = PersistenceService()

    private let coreData = CoreDataManager.shared
    private let sessionStore = SessionStore.shared
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private init() {}

    func ensureLocalIdentity() {
        let context = coreData.context
        _ = ensureCurrentMerchant(in: context)
        _ = ensureCurrentStaff(in: context)
        save(context)
    }

    @MainActor
    func fetchProducts() -> [ProductModel] {
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "isActive == YES")
        ]) else {
            return []
        }

        let request = Product.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)]
        request.predicate = predicate

        let products = (try? coreData.context.fetch(request)) ?? []
        return products.map { product in
            mapProduct(product)
        }
    }

    func saveProduct(_ productModel: ProductModel) {
        let context = coreData.context
        let product = fetchOrCreateProduct(id: productModel.id, in: context)
        apply(productModel, to: product)
        product.merchant = ensureCurrentMerchant(in: context)
        product.syncedAt = nil
        product.createdAt = product.createdAt ?? Date()
        save(context)
    }

    func deleteProduct(_ id: UUID) {
        let context = coreData.context
        if let product = findProduct(id: id, in: context) {
            let hasSalesHistory = ((product.saleLineItems as? Set<SaleLineItem>)?.isEmpty == false)
            if product.syncedAt != nil || hasSalesHistory {
                product.isActive = false
                product.syncedAt = nil
            } else {
                context.delete(product)
            }
            save(context)
        }
    }

    func fetchSales() -> [SaleSummary] {
        guard let predicate = merchantPredicate() else { return [] }

        let request = Sale.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.createdAt, ascending: false)]
        request.predicate = predicate

        let sales = (try? coreData.context.fetch(request)) ?? []
        return sales.map {
            SaleSummary(
                id: $0.id ?? UUID(),
                reference: $0.reference ?? "VND-0000",
                amount: decimal($0.totalAmount),
                paymentMethod: $0.paymentMethod ?? "Cash",
                staffName: $0.staff?.name ?? sessionStore.load()?.currentUser.name ?? "Staff",
                timestamp: $0.createdAt ?? Date()
            )
        }
    }

    @discardableResult
    func recordSale(cartItems: [CartItem], paymentMethod: String) -> String {
        let context = coreData.context
        guard let merchant = ensureCurrentMerchant(in: context) else { return "" }

        let sale = Sale(context: context)
        let now = Date()
        let reference = "VND-\(String(Int.random(in: 1...9999)).padded(to: 4))"
        let staff = ensureCurrentStaff(in: context)

        sale.id = UUID()
        sale.reference = reference
        sale.paymentMethod = paymentMethod
        sale.status = "completed"
        sale.createdAt = now
        sale.syncedAt = nil
        sale.totalAmount = ns(cartItems.reduce(0) { $0 + ($1.finalPrice * $1.quantity) })
        sale.merchant = merchant
        sale.staff = staff

        for cartItem in cartItems {
            let lineItem = SaleLineItem(context: context)
            lineItem.id = UUID()
            lineItem.createdAt = now
            lineItem.quantity = ns(cartItem.quantity)
            lineItem.unitPrice = ns(cartItem.finalPrice)
            lineItem.finalPrice = ns(cartItem.finalPrice)
            lineItem.originalPrice = ns(cartItem.product.suggestedPrice ?? cartItem.finalPrice)
            lineItem.discountAmount = ns(max(0, (cartItem.product.suggestedPrice ?? cartItem.finalPrice) - cartItem.finalPrice))
            lineItem.sale = sale
            lineItem.syncedAt = nil

            if let product = findProduct(id: cartItem.product.id, in: context) {
                lineItem.product = product

                if product.trackStock && !product.isService {
                    let nextQuantity = max(0, Int(product.stockQuantity) - NSDecimalNumber(decimal: cartItem.quantity).intValue)
                    product.stockQuantity = Int32(nextQuantity)
                    product.syncedAt = nil
                }
            }
        }

        save(context)
        return reference
    }

    func fetchMoneyState() -> MoneySnapshot {
        let context = coreData.context
        guard let predicate = merchantPredicate() else {
            return MoneySnapshot(
                matchedMoMo: 0,
                pendingMoMo: 0,
                unmatchedMoMo: 0,
                momoTransactions: [],
                creditEntries: [],
                availableSales: []
            )
        }

        let momoRequest = MoMoTransaction.fetchRequest()
        momoRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MoMoTransaction.receivedAt, ascending: false)]
        momoRequest.predicate = predicate
        let momoRecords = (try? context.fetch(momoRequest)) ?? []

        let creditRequest = CreditEntry.fetchRequest()
        creditRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CreditEntry.createdAt, ascending: false)]
        creditRequest.predicate = predicate
        let creditRecords = (try? context.fetch(creditRequest)) ?? []

        let matched = momoRecords.filter { ($0.status ?? "").lowercased() == "matched" }
        let pending = momoRecords.filter { ($0.status ?? "").lowercased() == "pending" }
        let unmatched = momoRecords.filter { ($0.status ?? "").lowercased() == "unmatched" }

        return MoneySnapshot(
            matchedMoMo: matched.reduce(0) { $0 + decimal($1.amount) },
            pendingMoMo: pending.reduce(0) { $0 + decimal($1.amount) },
            unmatchedMoMo: unmatched.reduce(0) { $0 + decimal($1.amount) },
            momoTransactions: momoRecords.map {
                MoMoTransactionSummary(
                    id: $0.id ?? UUID(),
                    reference: $0.transactionRef ?? "MoMo",
                    senderPhone: $0.senderPhone ?? "Unknown",
                    amount: decimal($0.amount),
                    status: (($0.status ?? "unmatched").capitalized),
                    timestamp: $0.receivedAt ?? $0.createdAt ?? Date()
                )
            },
            creditEntries: creditRecords.map {
                let originalAmount = decimal($0.amount)
                let repaidAmount = decimal($0.amountRepaid)
                let amountOwed = max(0, originalAmount - repaidAmount)
                let dueDate = $0.dueDate
                return CreditEntrySummary(
                    id: $0.id ?? UUID(),
                    customerName: $0.customerName ?? "Customer",
                    customerPhone: $0.customerPhone,
                    amountOwed: amountOwed,
                    originalAmount: originalAmount,
                    repaidAmount: repaidAmount,
                    dueDate: dueDate,
                    status: $0.status ?? "outstanding",
                    lastTransaction: $0.createdAt ?? Date(),
                    isOverdue: amountOwed > 0 && (dueDate.map { $0 < Calendar.current.startOfDay(for: Date()) } ?? false)
                )
            },
            availableSales: fetchSales()
        )
    }

    func addMoMoTransaction(reference: String, senderPhone: String, amount: Decimal, receivedAt: Date = Date()) {
        let context = coreData.context
        guard let merchant = ensureCurrentMerchant(in: context) else { return }
        let transaction = MoMoTransaction(context: context)
        transaction.id = UUID()
        transaction.transactionRef = reference
        transaction.senderPhone = senderPhone
        transaction.amount = ns(amount)
        transaction.status = "pending"
        transaction.receivedAt = receivedAt
        transaction.createdAt = Date()
        transaction.syncedAt = nil
        transaction.merchant = merchant
        save(context)
    }

    func matchMoMoTransaction(id: UUID, saleID: UUID?) {
        let context = coreData.context
        let request = MoMoTransaction.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return
        }
        request.predicate = predicate

        guard let transaction = try? context.fetch(request).first else { return }

        if let saleID, let sale = fetchSale(id: saleID, in: context) {
            transaction.sale = sale
            transaction.status = "matched"
        } else {
            transaction.sale = nil
            transaction.status = "pending"
        }

        transaction.syncedAt = nil
        save(context)
    }

    func updateMoMoTransactionStatus(id: UUID, status: String) {
        let context = coreData.context
        let request = MoMoTransaction.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return
        }
        request.predicate = predicate

        guard let transaction = try? context.fetch(request).first else { return }

        transaction.status = status.lowercased()
        if status.lowercased() != "matched" {
            transaction.sale = nil
        }

        transaction.syncedAt = nil
        save(context)
    }

    func createCreditEntry(customerName: String, customerPhone: String?, amount: Decimal, dueDate: Date?) {
        let context = coreData.context
        guard let merchant = ensureCurrentMerchant(in: context) else { return }
        let entry = CreditEntry(context: context)
        entry.id = UUID()
        entry.customerName = customerName
        entry.customerPhone = customerPhone
        entry.amount = ns(amount)
        entry.amountRepaid = ns(0)
        entry.status = "outstanding"
        entry.dueDate = dueDate
        entry.createdAt = Date()
        entry.syncedAt = nil
        entry.merchant = merchant
        save(context)
    }

    func recordCreditRepayment(id: UUID, amount: Decimal) {
        guard amount > 0 else { return }

        let context = coreData.context
        let request = CreditEntry.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return
        }
        request.predicate = predicate

        guard let entry = try? context.fetch(request).first else { return }

        let total = decimal(entry.amount)
        let repaid = min(total, decimal(entry.amountRepaid) + amount)
        entry.amountRepaid = ns(repaid)
        entry.status = repaid >= total ? "paid" : (repaid > 0 ? "partial" : "outstanding")
        entry.syncedAt = nil
        save(context)
    }

    func fetchLocalReportsSnapshot(timeframe: ReportTimeframe) -> LocalReportsSnapshot {
        let calendar = Calendar.current
        let now = Date()
        let currentWindow = timeframe.dateInterval(containing: now, calendar: calendar)
        let previousWindow = timeframe.previousDateInterval(from: currentWindow, calendar: calendar)

        let currentSales = fetchSales(in: currentWindow)
        let previousSales = fetchSales(in: previousWindow)
        let lineItems = fetchSaleLineItems(in: currentWindow)

        let totalRevenue = currentSales.reduce(0) { $0 + decimal($1.totalAmount) }
        let salesCount = currentSales.count
        let averageSale = salesCount > 0 ? totalRevenue / Decimal(salesCount) : 0

        var paymentBreakdown: [String: Decimal] = [:]
        for sale in currentSales {
            paymentBreakdown[sale.paymentMethod ?? "Cash", default: 0] += decimal(sale.totalAmount)
        }

        var productBuckets: [String: (units: Decimal, revenue: Decimal)] = [:]
        for lineItem in lineItems {
            let name = lineItem.product?.name ?? "Unnamed item"
            let units = decimal(lineItem.quantity)
            let revenue = decimal(lineItem.finalPrice) * units
            productBuckets[name, default: (0, 0)].units += units
            productBuckets[name, default: (0, 0)].revenue += revenue
        }

        let previousRevenue = previousSales.reduce(0) { $0 + decimal($1.totalAmount) }

        return LocalReportsSnapshot(
            totalRevenue: totalRevenue,
            salesCount: salesCount,
            averageSale: averageSale,
            previousRevenue: previousRevenue,
            paymentBreakdown: paymentBreakdown
                .map { ReportPaymentBreakdown(method: $0.key, amount: $0.value, salesCount: 0) }
                .sorted { $0.amount > $1.amount },
            topProducts: productBuckets
                .map { ReportTopProductRowModel(name: $0.key, sales: NSDecimalNumber(decimal: $0.value.units).intValue, revenue: $0.value.revenue) }
                .sorted { $0.revenue > $1.revenue }
                .prefix(5)
                .map { $0 },
            trend: timeframe.makeTrendPoints(from: currentSales, calendar: calendar)
        )
    }

    func applySyncPayload(_ payload: PullSyncPayload) {
        let context = coreData.backgroundContext()
        context.performAndWait {
            guard let merchant = ensureCurrentMerchant(in: context) else { return }

            for syncedStaff in payload.staff {
                let staff = fetchOrCreateStaff(id: syncedStaff.id, in: context)
                staff.id = syncedStaff.id
                staff.name = syncedStaff.name
                staff.role = syncedStaff.role
                staff.isActive = syncedStaff.isActive
                staff.createdAt = date(from: syncedStaff.createdAt)
                staff.syncedAt = Date()
                staff.merchant = merchant
                scrubSensitiveFields(from: staff)
            }

            for syncedProduct in payload.products {
                let product = fetchOrCreateProduct(id: syncedProduct.id, in: context)
                guard shouldApplyRemoteUpdate(to: product) else { continue }
                product.id = syncedProduct.id
                product.name = syncedProduct.name
                product.category = syncedProduct.category
                product.pricingType = syncedProduct.pricingType
                product.suggestedPrice = syncedProduct.suggestedPrice.map(ns)
                product.minPrice = syncedProduct.minPrice.map(ns)
                product.maxPrice = syncedProduct.maxPrice.map(ns)
                product.stockQuantity = Int32(syncedProduct.stockQuantity ?? 0)
                product.lowStockThreshold = Int32(syncedProduct.lowStockThreshold ?? 5)
                product.trackStock = syncedProduct.trackStock ?? true
                product.isService = syncedProduct.isService ?? false
                product.isActive = syncedProduct.isActive ?? true
                product.createdAt = date(from: syncedProduct.createdAt)
                product.syncedAt = Date()
                product.merchant = merchant
            }

            for syncedSale in payload.sales {
                let sale = fetchOrCreateSale(id: syncedSale.id, in: context)
                guard shouldApplyRemoteUpdate(to: sale) else { continue }
                sale.id = syncedSale.id
                sale.reference = syncedSale.reference
                sale.paymentMethod = syncedSale.paymentMethod
                sale.customerPhone = syncedSale.customerPhone
                sale.status = syncedSale.status
                sale.notes = syncedSale.notes
                sale.totalAmount = ns(syncedSale.totalAmount)
                sale.createdAt = date(from: syncedSale.createdAt)
                sale.syncedAt = Date()
                sale.merchant = merchant

                if let staffID = syncedSale.staffID {
                    sale.staff = fetchOrCreateStaff(id: staffID, in: context)
                }
            }

            for syncedLineItem in payload.saleLineItems {
                let lineItem = fetchOrCreateSaleLineItem(id: syncedLineItem.id, in: context)
                guard shouldApplyRemoteUpdate(to: lineItem) else { continue }
                lineItem.id = syncedLineItem.id
                lineItem.quantity = ns(syncedLineItem.quantity)
                lineItem.unitPrice = ns(syncedLineItem.unitPrice)
                lineItem.originalPrice = syncedLineItem.originalPrice.map(ns)
                lineItem.finalPrice = ns(syncedLineItem.finalPrice)
                lineItem.discountAmount = ns(syncedLineItem.discountAmount ?? 0)
                lineItem.discountReason = syncedLineItem.discountReason
                lineItem.priceOverrideBy = syncedLineItem.priceOverrideBy
                lineItem.createdAt = date(from: syncedLineItem.createdAt)
                lineItem.syncedAt = Date()
                lineItem.sale = fetchOrCreateSale(id: syncedLineItem.saleID, in: context)

                if let productID = syncedLineItem.productID {
                    lineItem.product = fetchOrCreateProduct(id: productID, in: context)
                }
            }

            for syncedMoMo in payload.momoTransactions {
                let momo = fetchOrCreateMoMo(id: syncedMoMo.id, in: context)
                guard shouldApplyRemoteUpdate(to: momo) else { continue }
                momo.id = syncedMoMo.id
                momo.transactionRef = syncedMoMo.transactionRef
                momo.senderPhone = syncedMoMo.senderPhone
                momo.amount = ns(syncedMoMo.amount)
                momo.status = syncedMoMo.status
                momo.receivedAt = date(from: syncedMoMo.receivedAt)
                momo.createdAt = date(from: syncedMoMo.createdAt)
                momo.syncedAt = Date()
                momo.merchant = merchant

                if let saleID = syncedMoMo.saleID {
                    momo.sale = fetchOrCreateSale(id: saleID, in: context)
                }
            }

            for syncedCredit in payload.creditEntries {
                let credit = fetchOrCreateCredit(id: syncedCredit.id, in: context)
                guard shouldApplyRemoteUpdate(to: credit) else { continue }
                credit.id = syncedCredit.id
                credit.customerName = syncedCredit.customerName
                credit.customerPhone = syncedCredit.customerPhone
                credit.amount = ns(syncedCredit.amount)
                credit.amountRepaid = ns(syncedCredit.amountRepaid ?? 0)
                credit.status = syncedCredit.status
                credit.dueDate = syncedCredit.dueDate.flatMap(date(from:))
                credit.createdAt = date(from: syncedCredit.createdAt)
                credit.syncedAt = Date()
                credit.merchant = merchant

                if let saleID = syncedCredit.saleID {
                    credit.sale = fetchOrCreateSale(id: saleID, in: context)
                }
            }

            scrubSensitiveFields(from: merchant)
            save(context)
        }
    }

    private func fetchSales(in interval: DateInterval) -> [Sale] {
        guard let merchantPredicate = merchantPredicate() else { return [] }

        let request = Sale.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.createdAt, ascending: true)]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            merchantPredicate,
            NSPredicate(format: "createdAt >= %@ AND createdAt < %@", interval.start as NSDate, interval.end as NSDate)
        ])
        return (try? coreData.context.fetch(request)) ?? []
    }

    private func fetchSaleLineItems(in interval: DateInterval) -> [SaleLineItem] {
        guard let saleMerchantPredicate = saleMerchantPredicate() else { return [] }

        let request = SaleLineItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SaleLineItem.createdAt, ascending: true)]
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            saleMerchantPredicate,
            NSPredicate(format: "sale.createdAt >= %@ AND sale.createdAt < %@", interval.start as NSDate, interval.end as NSDate)
        ])
        return (try? coreData.context.fetch(request)) ?? []
    }

    private func merchantPredicate() -> NSPredicate? {
        merchantPredicate(extraPredicates: [])
    }

    private func merchantPredicate(extraPredicates: [NSPredicate]) -> NSPredicate? {
        guard let merchantID = sessionStore.load()?.currentUser.merchantID else { return nil }
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "merchant.id == %@", merchantID as CVarArg)
        ] + extraPredicates)
    }

    private func saleMerchantPredicate() -> NSPredicate? {
        guard let merchantID = sessionStore.load()?.currentUser.merchantID else { return nil }
        return NSPredicate(format: "sale.merchant.id == %@", merchantID as CVarArg)
    }

    private func findProduct(id: UUID, in context: NSManagedObjectContext) -> Product? {
        let request = Product.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return nil
        }
        request.predicate = predicate
        return try? context.fetch(request).first
    }

    private func fetchSale(id: UUID, in context: NSManagedObjectContext) -> Sale? {
        let request = Sale.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return nil
        }
        request.predicate = predicate
        return try? context.fetch(request).first
    }

    private func fetchOrCreateProduct(id: UUID, in context: NSManagedObjectContext) -> Product {
        findProduct(id: id, in: context) ?? Product(context: context)
    }

    private func fetchOrCreateSale(id: UUID, in context: NSManagedObjectContext) -> Sale {
        fetchSale(id: id, in: context) ?? Sale(context: context)
    }

    private func fetchOrCreateSaleLineItem(id: UUID, in context: NSManagedObjectContext) -> SaleLineItem {
        let request = SaleLineItem.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request).first) ?? SaleLineItem(context: context)
    }

    private func fetchOrCreateMoMo(id: UUID, in context: NSManagedObjectContext) -> MoMoTransaction {
        let request = MoMoTransaction.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return MoMoTransaction(context: context)
        }
        request.predicate = predicate
        return (try? context.fetch(request).first) ?? MoMoTransaction(context: context)
    }

    private func fetchOrCreateCredit(id: UUID, in context: NSManagedObjectContext) -> CreditEntry {
        let request = CreditEntry.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return CreditEntry(context: context)
        }
        request.predicate = predicate
        return (try? context.fetch(request).first) ?? CreditEntry(context: context)
    }

    private func fetchOrCreateStaff(id: UUID, in context: NSManagedObjectContext) -> Staff {
        let request = Staff.fetchRequest()
        request.fetchLimit = 1
        guard let predicate = merchantPredicate(extraPredicates: [
            NSPredicate(format: "id == %@", id as CVarArg)
        ]) else {
            return Staff(context: context)
        }
        request.predicate = predicate
        return (try? context.fetch(request).first) ?? Staff(context: context)
    }

    private func ensureCurrentMerchant(in context: NSManagedObjectContext) -> Merchant? {
        guard let currentUser = sessionStore.load()?.currentUser else { return nil }

        let request = Merchant.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", currentUser.merchantID as CVarArg)
        let merchant = (try? context.fetch(request).first) ?? Merchant(context: context)

        merchant.id = currentUser.merchantID
        merchant.name = currentUser.businessName
        merchant.businessName = currentUser.businessName
        merchant.businessType = currentUser.businessType
        merchant.phone = currentUser.phone
        merchant.currency = currentUser.currency
        merchant.createdAt = merchant.createdAt ?? Date()
        merchant.syncedAt = merchant.syncedAt ?? Date()
        scrubSensitiveFields(from: merchant)
        return merchant
    }

    private func ensureCurrentStaff(in context: NSManagedObjectContext) -> Staff? {
        guard let currentUser = sessionStore.load()?.currentUser else { return nil }

        let request = Staff.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", currentUser.id as CVarArg)
        let staff = (try? context.fetch(request).first) ?? Staff(context: context)

        staff.id = currentUser.id
        staff.name = currentUser.name
        staff.role = currentUser.role.rawValue
        staff.isActive = true
        staff.createdAt = staff.createdAt ?? Date()
        staff.syncedAt = staff.syncedAt ?? Date()
        staff.merchant = ensureCurrentMerchant(in: context)
        scrubSensitiveFields(from: staff)
        return staff
    }

    private func apply(_ model: ProductModel, to product: Product) {
        product.id = model.id
        product.name = model.name
        product.category = model.category
        product.pricingType = model.pricingType.rawValue
        product.suggestedPrice = model.suggestedPrice.map(ns)
        product.minPrice = model.minPrice.map(ns)
        product.maxPrice = model.maxPrice.map(ns)
        product.stockQuantity = Int32(model.stockQuantity)
        product.lowStockThreshold = Int32(model.lowStockThreshold)
        product.trackStock = model.trackStock
        product.isService = model.isService
        product.isActive = model.isActive
    }

    private func save(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Core Data save failed: \(error.localizedDescription)")
            }
        }
    }

    private func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    private func mapProduct(_ product: Product) -> ProductModel {
        ProductModel(
            id: product.id ?? UUID(),
            name: product.name ?? "Unnamed Product",
            category: product.category ?? "General",
            pricingType: PricingType(rawValue: product.pricingType ?? "fixed") ?? .fixed,
            suggestedPrice: decimal(product.suggestedPrice),
            minPrice: decimal(product.minPrice),
            maxPrice: decimal(product.maxPrice),
            stockQuantity: Int(product.stockQuantity),
            lowStockThreshold: Int(product.lowStockThreshold),
            trackStock: product.trackStock,
            isService: product.isService,
            isActive: product.isActive
        )
    }

    private func shouldApplyRemoteUpdate(to object: NSManagedObject) -> Bool {
        if object.isInserted {
            return true
        }

        return (object.value(forKey: "syncedAt") as? Date) != nil
    }

    private func scrubSensitiveFields(from merchant: Merchant) {
        _ = merchant
    }

    private func scrubSensitiveFields(from staff: Staff) {
        _ = staff
    }
}

struct MoneySnapshot {
    let matchedMoMo: Decimal
    let pendingMoMo: Decimal
    let unmatchedMoMo: Decimal
    let momoTransactions: [MoMoTransactionSummary]
    let creditEntries: [CreditEntrySummary]
    let availableSales: [SaleSummary]
}

struct LocalReportsSnapshot {
    let totalRevenue: Decimal
    let salesCount: Int
    let averageSale: Decimal
    let previousRevenue: Decimal
    let paymentBreakdown: [ReportPaymentBreakdown]
    let topProducts: [ReportTopProductRowModel]
    let trend: [ChartDataPoint]
}

func decimal(_ value: NSDecimalNumber?) -> Decimal {
    value?.decimalValue ?? 0
}

func ns(_ value: Decimal) -> NSDecimalNumber {
    value as NSDecimalNumber
}

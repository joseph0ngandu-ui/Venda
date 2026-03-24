import Foundation
import CoreData

final class PersistenceService {
    static let shared = PersistenceService()

    private let coreData = CoreDataManager.shared
    private let sessionStore = SessionStore.shared
    private let formatter = ISO8601DateFormatter()

    private init() {}

    @MainActor
    func fetchProducts() -> [ProductModel] {
        let request = Product.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Product.createdAt, ascending: false)]

        let products = (try? coreData.context.fetch(request)) ?? []
        return products.map(Self.mapProduct)
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
            context.delete(product)
            save(context)
        }
    }

    func fetchSales() -> [SaleSummary] {
        let request = Sale.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Sale.createdAt, ascending: false)]

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
        let sale = Sale(context: context)
        let now = Date()
        let reference = "VND-\(String(Int.random(in: 1...9999)).padded(to: 4))"
        let merchant = ensureCurrentMerchant(in: context)
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
            }
        }

        save(context)
        return reference
    }

    func fetchMoneyState() -> MoneySnapshot {
        let context = coreData.context

        let momoRequest = MoMoTransaction.fetchRequest()
        momoRequest.sortDescriptors = [NSSortDescriptor(keyPath: \MoMoTransaction.receivedAt, ascending: false)]
        let momoRecords = (try? context.fetch(momoRequest)) ?? []

        let creditRequest = CreditEntry.fetchRequest()
        creditRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CreditEntry.createdAt, ascending: false)]
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
                    status: ($0.status ?? "unmatched").capitalized,
                    timestamp: $0.receivedAt ?? $0.createdAt ?? Date()
                )
            },
            creditEntries: creditRecords.map {
                let amount = decimal($0.amount)
                let repaid = decimal($0.amountRepaid)
                return CreditEntrySummary(
                    id: $0.id ?? UUID(),
                    customerName: $0.customerName ?? "Customer",
                    amountOwed: max(0, amount - repaid),
                    repaidAmount: repaid,
                    lastTransaction: $0.createdAt ?? Date()
                )
            }
        )
    }

    func applySyncPayload(_ payload: PullSyncPayload) {
        let context = coreData.backgroundContext()
        let merchant = ensureCurrentMerchant(in: context)

        for syncedStaff in payload.staff {
            let staff = fetchOrCreateStaff(id: syncedStaff.id, in: context)
            staff.id = syncedStaff.id
            staff.name = syncedStaff.name
            staff.role = syncedStaff.role
            staff.isActive = syncedStaff.isActive
            staff.createdAt = date(from: syncedStaff.createdAt)
            staff.syncedAt = Date()
            staff.merchant = merchant
        }

        for syncedProduct in payload.products {
            let product = fetchOrCreateProduct(id: syncedProduct.id, in: context)
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

        save(context)
    }

    private func findProduct(id: UUID, in context: NSManagedObjectContext) -> Product? {
        let request = Product.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return try? context.fetch(request).first
    }

    private func fetchOrCreateProduct(id: UUID, in context: NSManagedObjectContext) -> Product {
        findProduct(id: id, in: context) ?? Product(context: context)
    }

    private func fetchOrCreateSale(id: UUID, in context: NSManagedObjectContext) -> Sale {
        let request = Sale.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request).first) ?? Sale(context: context)
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
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request).first) ?? MoMoTransaction(context: context)
    }

    private func fetchOrCreateCredit(id: UUID, in context: NSManagedObjectContext) -> CreditEntry {
        let request = CreditEntry.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request).first) ?? CreditEntry(context: context)
    }

    private func fetchOrCreateStaff(id: UUID, in context: NSManagedObjectContext) -> Staff {
        let request = Staff.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        return (try? context.fetch(request).first) ?? Staff(context: context)
    }

    private func ensureCurrentMerchant(in context: NSManagedObjectContext) -> Merchant? {
        guard let currentUser = sessionStore.load()?.currentUser else { return nil }

        let request = Merchant.fetchRequest()
        request.fetchLimit = 1
        request.predicate = NSPredicate(format: "id == %@", currentUser.merchantID as CVarArg)
        let merchant = (try? context.fetch(request).first) ?? Merchant(context: context)
        merchant.id = currentUser.merchantID
        merchant.name = currentUser.name
        merchant.businessName = currentUser.businessName
        merchant.businessType = currentUser.businessType
        merchant.phone = currentUser.phone
        merchant.currency = currentUser.currency
        merchant.createdAt = merchant.createdAt ?? Date()
        merchant.syncedAt = merchant.syncedAt ?? Date()
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
        product.isService = model.isService
        product.isActive = true
        product.trackStock = true
    }

    private func save(_ context: NSManagedObjectContext) {
        if context.hasChanges {
            try? context.save()
        }
    }

    private func date(from string: String?) -> Date? {
        guard let string else { return nil }
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }

    private static func mapProduct(_ product: Product) -> ProductModel {
        ProductModel(
            id: product.id ?? UUID(),
            name: product.name ?? "Unnamed Product",
            category: product.category ?? "General",
            pricingType: PricingType(rawValue: product.pricingType ?? "fixed") ?? .fixed,
            suggestedPrice: decimal(product.suggestedPrice),
            minPrice: decimal(product.minPrice),
            maxPrice: decimal(product.maxPrice),
            isService: product.isService
        )
    }
}

struct MoneySnapshot {
    let matchedMoMo: Decimal
    let pendingMoMo: Decimal
    let unmatchedMoMo: Decimal
    let momoTransactions: [MoMoTransactionSummary]
    let creditEntries: [CreditEntrySummary]
}

func decimal(_ value: NSDecimalNumber?) -> Decimal {
    value?.decimalValue ?? 0
}

func ns(_ value: Decimal) -> NSDecimalNumber {
    value as NSDecimalNumber
}

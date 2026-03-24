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
    
    // Configured for the Tailscale Funnel homeserver URL
    private let syncURL = URL(string: "https://homeserver.taildbc5d3.ts.net/api/v1/sync/push")!
    
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
            await performSyncPush()
        }
    }
    
    private func performSyncPush() async {
        DispatchQueue.main.async { self.isSyncing = true }
        defer { DispatchQueue.main.async { self.isSyncing = false } }
        
        let context = CoreDataManager.shared.backgroundContext()
        
        do {
            // Find unsynced records
            let unsyncedSales = try fetchUnsynced(entity: Sale.self, in: context)
            let unsyncedProducts = try fetchUnsynced(entity: Product.self, in: context)
            let unsyncedStaff = try fetchUnsynced(entity: Staff.self, in: context)
            
            // If nothing to sync, return early
            if unsyncedSales.isEmpty && unsyncedProducts.isEmpty && unsyncedStaff.isEmpty {
                return
            }
            
            // Build the JSON payload 
            // In a real app we would map ManagedObjects to Codable DTOs
            // For this implementation scale, we simulate the structure
            var payload: [String: Any] = [:]
            
            if !unsyncedProducts.isEmpty {
                payload["products"] = unsyncedProducts.map { product in
                    [
                        "id": product.id?.uuidString ?? UUID().uuidString,
                        "name": product.name ?? "",
                        "category": product.category ?? "",
                        "pricing_type": product.pricingType ?? "fixed",
                        "stock_quantity": product.stockQuantity,
                        "created_at": isoString(from: product.createdAt),
                        "updated_at": isoString(from: Date())
                    ]
                }
            }
            
            // Note: Full mapping goes here for Sales, Line items, etc.
            
            // Send to homeserver API
            var request = URLRequest(url: syncURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Assuming JWT auth is handled by NetworkService or keychain
            // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Success: Mark as synced
                let now = Date()
                for object in unsyncedSales + unsyncedProducts + unsyncedStaff {
                    object.setValue(now, forKey: "syncedAt")
                }
                
                // Save context
                try context.save()
            }
            
        } catch {
            print("Sync failed: \(error.localizedDescription)")
        }
    }
    
    private func fetchUnsynced<T: NSManagedObject>(entity: T.Type, in context: NSManagedObjectContext) throws -> [T] {
        let fetchRequest = NSFetchRequest<T>(entityName: String(describing: T.self))
        fetchRequest.predicate = NSPredicate(format: "syncedAt == nil")
        return try context.fetch(fetchRequest)
    }
    
    private func isoString(from date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

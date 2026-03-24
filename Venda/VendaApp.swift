import SwiftUI

@main
struct VendaApp: App {
    @StateObject private var appState = AppState()
    
    // CoreData Context injection
    let persistenceController = CoreDataManager.shared
    
    // In a real implementation we would inject this environment into all ViewModels
    // For this prototype, we'll initialize basic ViewModels
    @StateObject private var dashboardViewModel = DashboardViewModel()
    @StateObject private var saleViewModel = SaleViewModel()
    @StateObject private var stockViewModel = StockViewModel()
    @StateObject private var moneyViewModel = MoneyViewModel()
    
    init() {
        // Start monitoring for network changes immediately on app launch
        SyncEngine.shared.startMonitoring()
    }

    var body: some Scene {
        WindowGroup {
            AppShellView()
                .environmentObject(appState)
                .environmentObject(dashboardViewModel)
                .environmentObject(saleViewModel)
                .environmentObject(stockViewModel)
                .environmentObject(moneyViewModel)
                .environment(\.managedObjectContext, persistenceController.context)
                // Inject the color scheme explicitly if desired, or let system handle
                .preferredColorScheme(nil) 
        }
    }
}

import SwiftUI

enum VendaTab: String, CaseIterable {
    case home, stock, money, more
    
    var title: String {
        switch self {
        case .home: return "Sell"
        case .stock: return "Stock"
        case .money: return "Money"
        case .more: return "More"
        }
    }
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .stock: return "shippingbox.fill"
        case .money: return "banknote.fill"
        case .more: return "line.3.horizontal"
        }
    }
}

struct VendaTabBar: View {
    @State private var selectedTab: VendaTab = .home
    
    @EnvironmentObject var saleViewModel: SaleViewModel
    @EnvironmentObject var stockViewModel: StockViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Main Content Area
            ZStack {
                switch selectedTab {
                case .home:
                    SellScreen(viewModel: saleViewModel, stockViewModel: stockViewModel)
                case .stock:
                    StockScreen(viewModel: stockViewModel)
                case .money:
                    MoneyScreen()
                case .more:
                    MoreScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // The Custom Tab Bar Component
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

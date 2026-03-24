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
    @EnvironmentObject var moneyViewModel: MoneyViewModel
    @EnvironmentObject var appState: AppState

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
                    MoneyWorkspaceScreen(viewModel: moneyViewModel)
                case .more:
                    SettingsWorkspaceScreen(appState: appState)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // The Custom Tab Bar Component
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

private struct MoneyWorkspaceScreen: View {
    @ObservedObject var viewModel: MoneyViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScreenSectionHeader(
                    title: "Money",
                    subtitle: "Mobile money and credit health"
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ScreenMetricCard(
                        label: "Matched MoMo",
                        value: viewModel.matchedMoMo.asZMW(),
                        detail: "\(viewModel.momoTransactions.filter { $0.status == "Matched" }.count) transactions",
                        icon: "checkmark.circle.fill",
                        tint: .vendaForest
                    )

                    ScreenMetricCard(
                        label: "Outstanding Credit",
                        value: viewModel.outstandingCredit.asZMW(),
                        detail: "\(viewModel.openCreditCustomers) customers",
                        icon: "clock.fill",
                        tint: .vendaEmber
                    )
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    ScreenSectionHeader(
                        title: "Recent MoMo",
                        subtitle: "Latest payment logs on this device"
                    )
                    .padding(.horizontal, 16)

                    if viewModel.momoTransactions.isEmpty {
                        EmptyStateCard(
                            icon: "iphone.gen3.radiowaves.left.and.right",
                            title: "No mobile money yet",
                            message: "Incoming MoMo activity will appear here after sync or local logging."
                        )
                        .padding(.horizontal, 16)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.momoTransactions.prefix(5)) { transaction in
                                VendaCard(accentColor: .vendaForest) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(transaction.reference)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.vendaInk)
                                            Text(transaction.senderPhone)
                                                .font(.system(size: 11))
                                                .foregroundColor(.vendaInkMid)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(transaction.amount.asZMW())
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.vendaInk)
                                            PaymentMethodBadge(method: transaction.status)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ScreenSectionHeader(
                        title: "Credit Book",
                        subtitle: "Open balances that still need follow-up"
                    )
                    .padding(.horizontal, 16)

                    if viewModel.creditEntries.isEmpty {
                        EmptyStateCard(
                            icon: "book.closed",
                            title: "No credit balances",
                            message: "Credit entries will show here once they are created or synced."
                        )
                        .padding(.horizontal, 16)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.creditEntries.prefix(5)) { entry in
                                VendaCard(accentColor: entry.isOverdue ? .vendaEmber : .vendaOchre) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(entry.customerName)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(.vendaInk)
                                            Text(entry.status.capitalized)
                                                .font(.system(size: 11))
                                                .foregroundColor(.vendaInkMid)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(entry.amountOwed.asZMW())
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(entry.isOverdue ? .vendaEmber : .vendaInk)
                                            if entry.isOverdue {
                                                Text("Overdue")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundColor(.vendaEmber)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.vendaSand)
        .scrollIndicators(.hidden)
    }
}

private struct SettingsWorkspaceScreen: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ProfileSummaryCard(
                    initials: initials,
                    name: appState.currentUser?.businessName ?? currentUserName,
                    subtitle: "\(appState.currentUser?.companyCode ?? "VND-0000") • \(appState.currentUser?.role.rawValue.capitalized ?? "Staff")",
                    badgeTitle: "Signed in as \(currentUserName)"
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                ScreenMetricCard(
                    label: "Session",
                    value: appState.isAuthenticated ? "Active" : "Signed Out",
                    detail: appState.currentUser?.phone ?? "No phone available",
                    icon: "person.crop.circle",
                    tint: .vendaForest
                )
                .padding(.horizontal, 16)

                EmptyStateCard(
                    icon: "gearshape.2",
                    title: "Settings hub",
                    message: "Account, support, and advanced admin tools are available in the full settings screen on branches where that target membership is enabled."
                )
                .padding(.horizontal, 16)

                VendaButton(
                    title: "Sign Out",
                    action: { appState.logout() },
                    isEnabled: true
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(Color.vendaSand)
        .scrollIndicators(.hidden)
    }

    private var currentUserName: String {
        appState.currentUser?.name ?? "Venda User"
    }

    private var initials: String {
        let parts = currentUserName.split(separator: " ")
        let letters = parts.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "V" : String(letters)
    }
}

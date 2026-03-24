import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: DashboardViewModel

    private var merchantName: String {
        appState.currentUser?.name ?? "Merchant"
    }

    private var merchantCode: String {
        appState.currentUser?.companyCode ?? "VND-0000"
    }

    private var initials: String {
        let parts = merchantName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return letters.isEmpty ? "V" : String(letters)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                ProfileSummaryCard(
                    initials: initials,
                    name: merchantName,
                    subtitle: "Running under \(merchantCode)",
                    badgeTitle: "Today, live overview"
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ScreenMetricCard(
                        label: "Today's revenue",
                        value: viewModel.totalRevenue.asZMW(),
                        detail: "Across \(viewModel.salesCount) sales",
                        icon: "banknote",
                        tint: .vendaForest
                    )

                    ScreenMetricCard(
                        label: "Payments",
                        value: "\(viewModel.paymentBreakdown.count)",
                        detail: "Methods in use",
                        icon: "creditcard",
                        tint: .vendaOchre
                    )
                }
                .padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 12) {
                    ScreenSectionHeader(
                        title: "Payment mix",
                        subtitle: "Where today’s money is landing"
                    )
                    .padding(.horizontal, 16)

                    if viewModel.paymentBreakdown.isEmpty {
                        EmptyStateCard(
                            icon: "chart.pie",
                            title: "No transactions yet",
                            message: "Once sales come in, we’ll break down cash, mobile money, and credit here."
                        )
                        .padding(.horizontal, 16)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.paymentBreakdown, id: \.method) { item in
                                    PaymentBreakdownPill(label: item.method, amount: item.amount)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ScreenSectionHeader(
                        title: "Recent sales",
                        subtitle: "The latest activity from the floor"
                    )
                    .padding(.horizontal, 16)

                    if viewModel.recentSales.isEmpty {
                        EmptyStateCard(
                            icon: "cart",
                            title: "Sales will appear here",
                            message: "Your first completed sale will show up in this feed with its reference and payment method."
                        )
                        .padding(.horizontal, 16)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(viewModel.recentSales) { sale in
                                SaleRowView(sale: sale)
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

private struct PaymentBreakdownPill: View {
    let label: String
    let amount: Decimal

    var body: some View {
        VendaCard(accentColor: .vendaOchre) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundColor(.vendaInkLt)
                Text(amount.asZMW())
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.vendaOchre)
            }
        }
    }
}

private struct SaleRowView: View {
    let sale: SaleSummary

    var body: some View {
        VendaCard(accentColor: .vendaForest) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.vendaForestLt)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(sale.reference.suffix(2)))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.vendaForestDk)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(sale.reference)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(sale.staffName)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                    Text(sale.timestamp.asVendaTime())
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkLt)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(sale.amount.asZMW())
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    PaymentMethodBadge(method: sale.paymentMethod)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    let viewModel = DashboardViewModel()
    viewModel.updateMetrics(from: [
        SaleSummary(id: UUID(), reference: "VND-0001", amount: 850, paymentMethod: "Cash", staffName: "Kasela", timestamp: Date()),
        SaleSummary(id: UUID(), reference: "VND-0002", amount: 1200, paymentMethod: "MTN MoMo", staffName: "Chanda", timestamp: Date()),
    ])
    return HomeScreen(viewModel: viewModel)
}

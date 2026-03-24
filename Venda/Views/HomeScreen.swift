import SwiftUI

struct HomeScreen: View {
    @ObservedObject var viewModel: DashboardViewModel
    @State private var showLowStockBanner = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good morning,")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.white.opacity(0.65))
                            Text("Woodlands Salon")
                                .font(.system(size: 22, weight: .semibold, design: .default))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Circle()
                            .fill(Color.vendaForestDk)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text("WS")
                                    .font(.system(size: 14, weight: .bold, design: .default))
                                    .foregroundColor(.white)
                            )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Stats
                    HStack(spacing: 12) {
                        VendaCard(backgroundColor: .vendaForestDk.opacity(0.8), borderColor: .white.opacity(0.2)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today's revenue")
                                    .font(.system(size: 11, weight: .medium, design: .default))
                                    .foregroundColor(.white.opacity(0.7))
                                Text(viewModel.totalRevenue.asZMW())
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }

                        VendaCard(backgroundColor: .vendaForestDk.opacity(0.8), borderColor: .white.opacity(0.2)) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sales today")
                                    .font(.system(size: 11, weight: .medium, design: .default))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("\(viewModel.salesCount)")
                                    .font(.system(size: 18, weight: .semibold, design: .default))
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .background(Color.vendaForest)

                // Content
                ScrollView {
                    VStack(spacing: 16) {
                        // Payment breakdown
                        if !viewModel.paymentBreakdown.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.paymentBreakdown, id: \.method) { item in
                                        PaymentBreakdownPill(label: item.method, amount: item.amount)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        // Recent sales
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent sales")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .textCase(.uppercase)
                                .tracking(0.5)
                                .foregroundColor(.vendaInkLt)
                                .padding(.horizontal, 16)

                            if viewModel.recentSales.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "cart")
                                        .font(.system(size: 32, weight: .light))
                                        .foregroundColor(.vendaInkLt)
                                    Text("Your sales will appear here")
                                        .font(.system(size: 14, weight: .medium, design: .default))
                                        .foregroundColor(.vendaInkMid)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 32)
                            } else {
                                ForEach(viewModel.recentSales) { sale in
                                    SaleRowView(sale: sale)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }
                .background(Color.vendaSand)
            }
        }
    }
}

private struct PaymentBreakdownPill: View {
    let label: String
    let amount: Decimal

    var body: some View {
        VendaCard {
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
        VendaCard {
            HStack(spacing: 12) {
                Image(systemName: "scissors")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.vendaForest)
                    .frame(width: 36, height: 36)
                    .background(Color.vendaForestLt)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Service")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(sale.staffName)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
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

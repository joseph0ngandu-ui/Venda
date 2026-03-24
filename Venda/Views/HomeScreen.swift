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
            VStack(spacing: DesignSystem.Spacing.xl) {
                ProfileSummaryCard(
                    initials: initials,
                    name: merchantName,
                    subtitle: "Running under \(merchantCode)",
                    badgeTitle: "Today, live overview"
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                    GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                ], spacing: DesignSystem.Spacing.md) {
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
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ScreenSectionHeader(
                        title: "Payment mix",
                        subtitle: "Where today's money is landing"
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if viewModel.paymentBreakdown.isEmpty {
                        EmptyStateCard(
                            icon: "chart.pie",
                            title: "No transactions yet",
                            message: "Once sales come in, we’ll break down cash, mobile money, and credit here."
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(viewModel.paymentBreakdown, id: \.method) { item in
                                    PaymentBreakdownPill(label: item.method, amount: item.amount)
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ScreenSectionHeader(
                        title: "Recent sales",
                        subtitle: "The latest activity from the floor"
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if viewModel.recentSales.isEmpty {
                        EmptyStateCard(
                            icon: "cart",
                            title: "Sales will appear here",
                            message: "Your first completed sale will show up in this feed with its reference and payment method."
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(viewModel.recentSales) { sale in
                                SaleRowView(sale: sale)
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
                .padding(.bottom, DesignSystem.Spacing.xxxl)
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(label)
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaInkLt)
                Text(amount.asZMW())
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.vendaOchre)
            }
        }
    }
}

private struct SaleRowView: View {
    let sale: SaleSummary

    var body: some View {
        VendaCard(accentColor: .vendaForest) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Circle()
                    .fill(Color.vendaForestLt)
                    .frame(
                        width: DesignSystem.ComponentSize.avatarSmall,
                        height: DesignSystem.ComponentSize.avatarSmall
                    )
                    .overlay(
                        Text(String(sale.reference.suffix(2)))
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.vendaForestDk)
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(sale.reference)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.vendaInk)
                    Text(sale.staffName)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                    Text(sale.timestamp.asVendaTime())
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkLt)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    Text(sale.amount.asZMW())
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.vendaInk)
                    PaymentMethodBadge(method: sale.paymentMethod)
                }
            }
        }
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

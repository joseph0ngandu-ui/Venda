import SwiftUI

struct ReportsScreen: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReportsViewModel()

    private var topPaymentMethod: ReportPaymentBreakdown? {
        viewModel.paymentBreakdown.first
    }

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.md)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Analytics")
                            .font(DesignSystem.Typography.h4)
                            .foregroundColor(.vendaInk)
                        Text(viewModel.usingOfflineSnapshot ? "Offline snapshot" : "Live business performance")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInkMid)
                    }

                    Spacer()

                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Picker("", selection: $viewModel.selectedTimeframe) {
                            ForEach(ReportTimeframe.allCases, id: \.rawValue) { timeframe in
                                Text(timeframe.title).tag(timeframe)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        VendaCard(backgroundColor: .vendaForestDk) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                HStack {
                                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                        Text("Total Revenue")
                                            .font(DesignSystem.Typography.label)
                                            .foregroundColor(.white.opacity(0.75))
                                        Text(viewModel.totalRevenue.asZMW())
                                            .font(DesignSystem.Typography.h1)
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }

                                Text(viewModel.trendSummary)
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(.vendaOchre)

                                if let errorMessage = viewModel.errorMessage, viewModel.usingOfflineSnapshot {
                                    Text("Showing local data because live reports are unavailable: \(errorMessage)")
                                        .font(DesignSystem.Typography.captionSmall)
                                        .foregroundColor(.white.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                            GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                        ], spacing: DesignSystem.Spacing.md) {
                            ScreenMetricCard(
                                label: "Sales Count",
                                value: "\(viewModel.salesCount)",
                                detail: "Completed transactions in this period",
                                icon: "cart.fill",
                                tint: .vendaForest
                            )

                            ScreenMetricCard(
                                label: "Average Sale",
                                value: viewModel.averageSale.asZMW(),
                                detail: topPaymentMethod == nil ? "No payment mix yet" : "Top method: \(topPaymentMethod?.method ?? "N/A")",
                                icon: "chart.bar.fill",
                                tint: .vendaOchre
                            )
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            ScreenSectionHeader(
                                title: "Sales Trend",
                                subtitle: "Revenue distribution for the selected period"
                            )
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                            if viewModel.trend.allSatisfy({ $0.value == 0 }) {
                                EmptyStateCard(
                                    icon: "chart.bar.xaxis",
                                    title: "Not enough sales data yet",
                                    message: "Complete a few sales and we’ll map the trend here automatically."
                                )
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            } else {
                                VendaCard {
                                    GeometryReader { geometry in
                                        HStack(alignment: .bottom, spacing: 0) {
                                            let maxValue = max(NSDecimalNumber(decimal: viewModel.maxTrendValue).doubleValue, 1)

                                            ForEach(viewModel.trend) { point in
                                                let amount = NSDecimalNumber(decimal: point.value).doubleValue
                                                let ratio = amount / maxValue
                                                let barHeight = max(CGFloat(ratio) * geometry.size.height, 8)
                                                let isPeak = point.value == viewModel.maxTrendValue && point.value > 0

                                                VStack(spacing: DesignSystem.Spacing.sm) {
                                                    Spacer(minLength: 0)

                                                    if isPeak {
                                                        Text(point.value.asZMW())
                                                            .font(DesignSystem.Typography.caption)
                                                            .foregroundColor(.vendaInkMid)
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.7)
                                                    }

                                                    RoundedRectangle(cornerRadius: DesignSystem.Radius.sm)
                                                        .fill(isPeak ? Color.vendaForest : Color.vendaForestLt)
                                                        .frame(height: barHeight)
                                                        .padding(.horizontal, DesignSystem.Spacing.xs)

                                                    Text(point.label)
                                                        .font(DesignSystem.Typography.caption)
                                                        .foregroundColor(.vendaInkLt)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.7)
                                                }
                                                .frame(width: geometry.size.width / CGFloat(max(viewModel.trend.count, 1)))
                                            }
                                        }
                                    }
                                    .frame(height: 210)
                                    .padding(.top, DesignSystem.Spacing.md)
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            ScreenSectionHeader(
                                title: "Payment Mix",
                                subtitle: "How customers are paying right now"
                            )
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                            if viewModel.paymentBreakdown.isEmpty {
                                EmptyStateCard(
                                    icon: "creditcard.trianglebadge.exclamationmark",
                                    title: "No payment data available",
                                    message: "Payment channels will appear here once sales start syncing or are recorded locally."
                                )
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            } else {
                                LazyVStack(spacing: DesignSystem.Spacing.md) {
                                    ForEach(viewModel.paymentBreakdown) { item in
                                        ReportPaymentRow(item: item)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                            ScreenSectionHeader(
                                title: "Top Performers",
                                subtitle: "Products or services generating the most revenue"
                            )
                            .padding(.horizontal, DesignSystem.Spacing.lg)

                            if viewModel.topProducts.isEmpty {
                                EmptyStateCard(
                                    icon: "shippingbox",
                                    title: "No product movement yet",
                                    message: "As soon as sales include stocked items or services, top performers will rank themselves here."
                                )
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            } else {
                                LazyVStack(spacing: DesignSystem.Spacing.md) {
                                    ForEach(viewModel.topProducts) { product in
                                        TopProductRow(name: product.name, sales: product.sales, revenue: product.revenue)
                                    }
                                }
                                .padding(.horizontal, DesignSystem.Spacing.lg)
                            }
                        }

                        Spacer(minLength: DesignSystem.Spacing.xl)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task(id: viewModel.selectedTimeframe) {
            await viewModel.load(token: appState.authToken)
        }
    }
}

private struct ReportPaymentRow: View {
    let item: ReportPaymentBreakdown

    var body: some View {
        VendaCard(accentColor: .vendaOchre) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(item.method)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.vendaInk)
                    Text(item.salesCount > 0 ? "\(item.salesCount) sales" : "Local summary")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                Text(item.amount.asZMW())
                    .font(DesignSystem.Typography.bodySemibold)
                    .foregroundColor(.vendaOchreDk)
            }
        }
    }
}

private struct TopProductRow: View {
    let name: String
    let sales: Int
    let revenue: Decimal

    var body: some View {
        VendaCard {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(name)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.vendaInk)
                    Text("\(sales) sold")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                Text(revenue.asZMW())
                    .font(DesignSystem.Typography.bodySemibold)
                    .foregroundColor(.vendaForest)
            }
        }
    }
}

#Preview {
    ReportsScreen()
        .environmentObject(AppState())
}

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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Analytics")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        Text(viewModel.usingOfflineSnapshot ? "Offline snapshot" : "Live business performance")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }

                    Spacer()

                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Picker("", selection: $viewModel.selectedTimeframe) {
                            ForEach(ReportTimeframe.allCases, id: \.rawValue) { timeframe in
                                Text(timeframe.title).tag(timeframe)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)

                        VendaCard(backgroundColor: .vendaForestDk) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Total Revenue")
                                            .font(.system(size: 13, weight: .medium, design: .default))
                                            .foregroundColor(.white.opacity(0.75))
                                        Text(viewModel.totalRevenue.asZMW())
                                            .font(.system(size: 30, weight: .bold, design: .default))
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                }

                                Text(viewModel.trendSummary)
                                    .font(.system(size: 12, weight: .medium, design: .default))
                                    .foregroundColor(.vendaOchre)

                                if let errorMessage = viewModel.errorMessage, viewModel.usingOfflineSnapshot {
                                    Text("Showing local data because live reports are unavailable: \(errorMessage)")
                                        .font(.system(size: 11, weight: .regular, design: .default))
                                        .foregroundColor(.white.opacity(0.72))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 12),
                            GridItem(.flexible(), spacing: 12)
                        ], spacing: 12) {
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
                        .padding(.horizontal, 16)

                        VStack(alignment: .leading, spacing: 14) {
                            ScreenSectionHeader(
                                title: "Sales Trend",
                                subtitle: "Revenue distribution for the selected period"
                            )
                            .padding(.horizontal, 16)

                            if viewModel.trend.allSatisfy({ $0.value == 0 }) {
                                EmptyStateCard(
                                    icon: "chart.bar.xaxis",
                                    title: "Not enough sales data yet",
                                    message: "Complete a few sales and we’ll map the trend here automatically."
                                )
                                .padding(.horizontal, 16)
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

                                                VStack(spacing: 8) {
                                                    Spacer(minLength: 0)

                                                    if isPeak {
                                                        Text(point.value.asZMW())
                                                            .font(.system(size: 9, weight: .semibold, design: .default))
                                                            .foregroundColor(.vendaInkMid)
                                                            .lineLimit(1)
                                                            .minimumScaleFactor(0.7)
                                                    }

                                                    RoundedRectangle(cornerRadius: 6)
                                                        .fill(isPeak ? Color.vendaForest : Color.vendaForestLt)
                                                        .frame(height: barHeight)
                                                        .padding(.horizontal, 4)

                                                    Text(point.label)
                                                        .font(.system(size: 11, weight: .medium, design: .default))
                                                        .foregroundColor(.vendaInkLt)
                                                        .lineLimit(1)
                                                        .minimumScaleFactor(0.7)
                                                }
                                                .frame(width: geometry.size.width / CGFloat(max(viewModel.trend.count, 1)))
                                            }
                                        }
                                    }
                                    .frame(height: 210)
                                    .padding(.top, 12)
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            ScreenSectionHeader(
                                title: "Payment Mix",
                                subtitle: "How customers are paying right now"
                            )
                            .padding(.horizontal, 16)

                            if viewModel.paymentBreakdown.isEmpty {
                                EmptyStateCard(
                                    icon: "creditcard.trianglebadge.exclamationmark",
                                    title: "No payment data available",
                                    message: "Payment channels will appear here once sales start syncing or are recorded locally."
                                )
                                .padding(.horizontal, 16)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.paymentBreakdown) { item in
                                        ReportPaymentRow(item: item)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            ScreenSectionHeader(
                                title: "Top Performers",
                                subtitle: "Products or services generating the most revenue"
                            )
                            .padding(.horizontal, 16)

                            if viewModel.topProducts.isEmpty {
                                EmptyStateCard(
                                    icon: "shippingbox",
                                    title: "No product movement yet",
                                    message: "As soon as sales include stocked items or services, top performers will rank themselves here."
                                )
                                .padding(.horizontal, 16)
                            } else {
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.topProducts) { product in
                                        TopProductRow(name: product.name, sales: product.sales, revenue: product.revenue)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }

                        Spacer(minLength: 24)
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.method)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(item.salesCount > 0 ? "\(item.salesCount) sales" : "Local summary")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                Text(item.amount.asZMW())
                    .font(.system(size: 14, weight: .semibold, design: .default))
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text("\(sales) sold")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                Text(revenue.asZMW())
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.vendaForest)
            }
        }
    }
}

#Preview {
    ReportsScreen()
        .environmentObject(AppState())
}

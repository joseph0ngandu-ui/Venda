import SwiftUI

struct MoneyScreen: View {
    @ObservedObject var viewModel: MoneyViewModel
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Money")
                        .font(.system(size: 22, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // Segmented control
                Picker("", selection: $selectedTab) {
                    Text("MoMo").tag(0)
                    Text("Credit").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if selectedTab == 0 {
                    MoMoReconciliationView(viewModel: viewModel)
                } else {
                    CreditBookView(viewModel: viewModel)
                }
            }
        }
    }
}

private struct MoMoReconciliationView: View {
    @ObservedObject var viewModel: MoneyViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Status cards
                HStack(spacing: 8) {
                    StatusCard(
                        label: "Matched",
                        amount: viewModel.matchedMoMo,
                        color: .vendaForest,
                        count: viewModel.momoTransactions.filter { $0.status == "Matched" }.count
                    )
                    StatusCard(
                        label: "Pending",
                        amount: viewModel.pendingMoMo,
                        color: .vendaOchre,
                        count: viewModel.momoTransactions.filter { $0.status == "Pending" }.count
                    )
                    StatusCard(
                        label: "Unmatched",
                        amount: viewModel.unmatchedMoMo,
                        color: .vendaEmber,
                        count: viewModel.momoTransactions.filter { $0.status == "Unmatched" }.count
                    )
                }
                .padding(.horizontal, 16)

                // Transactions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent payments")
                        .font(.system(size: 12, weight: .semibold, design: .default))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .foregroundColor(.vendaInkLt)
                        .padding(.horizontal, 16)

                    if viewModel.momoTransactions.isEmpty {
                        VStack(spacing: 12) {
                            Text("No recent payments.")
                                .font(.system(size: 14, weight: .medium, design: .default))
                                .foregroundColor(.vendaInkMid)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(viewModel.momoTransactions) { tx in
                                TransactionRow(
                                    reference: tx.reference,
                                    senderPhone: tx.senderPhone,
                                    amount: tx.amount,
                                    status: tx.status,
                                    timestamp: tx.timestamp
                                )
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
}

private struct CreditBookView: View {
    @ObservedObject var viewModel: MoneyViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Outstanding credit")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundColor(.vendaInkLt)
                    .padding(.horizontal, 16)

                if viewModel.creditEntries.isEmpty {
                    VStack(spacing: 12) {
                        Text("No outstanding credit \u{2014} nice.")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.vendaInkMid)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.vendaForest)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.creditEntries) { entry in
                            CreditEntryRow(
                                customerName: entry.customerName,
                                amountOwed: entry.amountOwed,
                                lastTransaction: entry.lastTransaction,
                                repaidAmount: entry.repaidAmount
                            )
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
    }
}

private struct StatusCard: View {
    let label: String
    let amount: Decimal
    let color: Color
    let count: Int

    var body: some View {
        VendaCard {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .foregroundColor(.vendaInkLt)
                }
                Text(amount.asZMW())
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(color)
                Text("\(count) trans.")
                    .font(.system(size: 9, weight: .regular, design: .default))
                    .foregroundColor(.vendaInkMid)
            }
        }
    }
}

private struct TransactionRow: View {
    let reference: String
    let senderPhone: String
    let amount: Decimal
    let status: String
    let timestamp: Date

    var body: some View {
        VendaCard {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 2) {
                    Text(reference)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(.vendaInkMid)
                }
                .frame(width: 40, height: 40)
                .background(Color.vendaParchment)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(senderPhone)
                        .font(.system(size: 12, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(timestamp.asVendaTime())
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(amount.asZMW())
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    PaymentMethodBadge(method: status)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct CreditEntryRow: View {
    let customerName: String
    let amountOwed: Decimal
    let lastTransaction: Date
    let repaidAmount: Decimal

    var body: some View {
        VendaCard(accentColor: .vendaEmber) {
            HStack(spacing: 12) {
                VStack(alignment: .center, spacing: 0) {
                    Text(String(customerName.prefix(1)))
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.white)
                }
                .frame(width: 40, height: 40)
                .background(Color.vendaEmber)
                .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(customerName)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(lastTransaction.asVendaTime())
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(amountOwed.asZMW())
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.vendaEmber)
                    Text("\(repaidAmount.asZMW()) repaid")
                        .font(.system(size: 9, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    MoneyScreen(viewModel: MoneyViewModel())
}

import SwiftUI

struct MoneyScreen: View {
    @ObservedObject var viewModel: MoneyViewModel
    @State private var selectedTab: MoneyLedgerTab = .momo
    @State private var showingMoMoEntry = false
    @State private var showingCreditEntry = false
    @State private var selectedTransactionForMatch: MoMoTransactionSummary?
    @State private var selectedCreditForRepayment: CreditEntrySummary?
    @State private var momoFilter: MoneyStatusFilter = .all

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Money")
                            .font(DesignSystem.Typography.h2)
                            .foregroundColor(.vendaInk)
                        Text("Reconciliation, credit, and cash discipline")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInkMid)
                    }
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)

                Picker("", selection: $selectedTab) {
                    Text("MoMo").tag(MoneyLedgerTab.momo)
                    Text("Credit").tag(MoneyLedgerTab.credit)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)

                if selectedTab == .momo {
                    MoMoReconciliationView(
                        viewModel: viewModel,
                        filter: $momoFilter,
                        onAdd: { showingMoMoEntry = true },
                        onMatch: { selectedTransactionForMatch = $0 }
                    )
                } else {
                    CreditBookView(
                        viewModel: viewModel,
                        onAdd: { showingCreditEntry = true },
                        onRepay: { selectedCreditForRepayment = $0 }
                    )
                }
            }
        }
        .onAppear {
            viewModel.refreshData()
        }
        .sheet(isPresented: $showingMoMoEntry) {
            AddMoMoSheet { reference, senderPhone, amount in
                viewModel.addMoMo(reference: reference, senderPhone: senderPhone, amount: amount)
            }
        }
        .sheet(isPresented: $showingCreditEntry) {
            AddCreditSheet { customerName, customerPhone, amount, dueDate in
                viewModel.addCredit(customerName: customerName, customerPhone: customerPhone, amount: amount, dueDate: dueDate)
            }
        }
        .sheet(item: $selectedTransactionForMatch) { transaction in
            MatchTransactionSheet(
                transaction: transaction,
                sales: viewModel.availableSales,
                onMatch: { saleID in
                    viewModel.matchMoMo(id: transaction.id, saleID: saleID)
                },
                onStatusChange: { status in
                    viewModel.updateMoMoStatus(id: transaction.id, status: status)
                }
            )
        }
        .sheet(item: $selectedCreditForRepayment) { entry in
            RecordRepaymentSheet(entry: entry) { amount in
                viewModel.repayCredit(id: entry.id, amount: amount)
            }
        }
    }
}

private enum MoneyLedgerTab {
    case momo
    case credit
}

private enum MoneyStatusFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case matched = "Matched"
    case pending = "Pending"
    case unmatched = "Unmatched"

    var id: String { rawValue }
}

private struct MoMoReconciliationView: View {
    @ObservedObject var viewModel: MoneyViewModel
    @Binding var filter: MoneyStatusFilter
    let onAdd: () -> Void
    let onMatch: (MoMoTransactionSummary) -> Void

    private var filteredTransactions: [MoMoTransactionSummary] {
        guard filter != .all else { return viewModel.momoTransactions }
        return viewModel.momoTransactions.filter { $0.status.caseInsensitiveCompare(filter.rawValue) == .orderedSame }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
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
                        StatusCard(
                            label: "Volume",
                            amount: viewModel.totalMoMoVolume,
                            color: .vendaInk,
                            count: viewModel.momoTransactions.count
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                HStack {
                    Menu {
                        ForEach(MoneyStatusFilter.allCases) { option in
                            Button(option.rawValue) {
                                filter = option
                            }
                        }
                    } label: {
                        Label(filter.rawValue, systemImage: "line.3.horizontal.decrease.circle")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInk)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                                    .stroke(Color.vendaLine, lineWidth: 1)
                            )
                    }

                    Spacer()

                    Button(action: onAdd) {
                        Label("Log payment", systemImage: "plus")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaForest)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.vendaForestLt)
                            .cornerRadius(DesignSystem.Radius.md)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ScreenSectionHeader(
                        title: "Recent Payments",
                        subtitle: "Review incoming transfers and reconcile them to sales"
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if filteredTransactions.isEmpty {
                        EmptyStateCard(
                            icon: "iphone.gen3.radiowaves.left.and.right",
                            title: "No MoMo activity in this view",
                            message: "Use Log payment to register an incoming transfer or switch the filter to inspect other statuses."
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(filteredTransactions) { transaction in
                                TransactionRow(
                                    transaction: transaction,
                                    onMatch: { onMatch(transaction) },
                                    onStatusChange: { status in
                                        viewModel.updateMoMoStatus(id: transaction.id, status: status)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
        }
    }
}

private struct CreditBookView: View {
    @ObservedObject var viewModel: MoneyViewModel
    let onAdd: () -> Void
    let onRepay: (CreditEntrySummary) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DesignSystem.Spacing.lg) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        StatusCard(
                            label: "Outstanding",
                            amount: viewModel.outstandingCredit,
                            color: .vendaEmber,
                            count: viewModel.openCreditCustomers
                        )
                        StatusCard(
                            label: "Overdue",
                            amount: viewModel.overdueCredit,
                            color: .vendaOchre,
                            count: viewModel.overdueCreditCount
                        )
                        StatusCard(
                            label: "Repaid",
                            amount: viewModel.creditEntries.reduce(0) { $0 + $1.repaidAmount },
                            color: .vendaForest,
                            count: viewModel.creditEntries.count
                        )
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }

                HStack {
                    Text("Track handover balances and customer credit from one place.")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                    Spacer()
                    Button(action: onAdd) {
                        Label("Record credit", systemImage: "plus")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaEmber)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(Color.vendaEmberLt)
                            .cornerRadius(DesignSystem.Radius.md)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ScreenSectionHeader(
                        title: "Credit Ledger",
                        subtitle: "Outstanding balances, repayments, and due dates"
                    )
                    .padding(.horizontal, DesignSystem.Spacing.lg)

                    if viewModel.creditEntries.isEmpty {
                        EmptyStateCard(
                            icon: "checkmark.circle",
                            title: "No credit balances right now",
                            message: "When you extend credit, the running balance and repayment history will appear here."
                        )
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    } else {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            ForEach(viewModel.creditEntries) { entry in
                                CreditEntryRow(
                                    entry: entry,
                                    onRepay: { onRepay(entry) },
                                    onSettle: { viewModel.settleCredit(id: entry.id) }
                                )
                            }
                        }
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                    }
                }
            }
            .padding(.vertical, DesignSystem.Spacing.lg)
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
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.vendaInkLt)
                }
                Text(amount.asZMW())
                    .font(DesignSystem.Typography.label)
                    .foregroundColor(color)
                Text("\(count) entries")
                    .font(DesignSystem.Typography.captionSmall)
                    .foregroundColor(.vendaInkMid)
            }
            .frame(width: 120, alignment: .leading)
        }
    }
}

private struct TransactionRow: View {
    let transaction: MoMoTransactionSummary
    let onMatch: () -> Void
    let onStatusChange: (String) -> Void

    var body: some View {
        VendaCard(accentColor: statusColor) {
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text(String(transaction.reference.suffix(4)))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.vendaInkMid)
                }
                .frame(width: 42, height: 42)
                .background(Color.vendaParchment)
                .cornerRadius(DesignSystem.Radius.md)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(transaction.senderPhone)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.vendaInk)
                    Text(transaction.reference)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                    Text(transaction.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkLt)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.sm) {
                    Text(transaction.amount.asZMW())
                        .font(DesignSystem.Typography.bodySemibold)
                        .foregroundColor(.vendaInk)
                    ReconciliationStatusBadge(status: transaction.status)
                }

                Menu {
                    if transaction.status != "Matched" {
                        Button("Match to sale") { onMatch() }
                    }
                    Button("Mark pending") { onStatusChange("pending") }
                    Button("Mark unmatched") { onStatusChange("unmatched") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.vendaInkLt)
                }
            }
        }
    }

    private var statusColor: Color {
        switch transaction.status.lowercased() {
        case "matched": return .vendaForest
        case "pending": return .vendaOchre
        case "unmatched": return .vendaEmber
        default: return .vendaLine
        }
    }
}

private struct CreditEntryRow: View {
    let entry: CreditEntrySummary
    let onRepay: () -> Void
    let onSettle: () -> Void

    var body: some View {
        VendaCard(accentColor: entry.isOverdue ? .vendaOchre : .vendaEmber) {
            HStack(spacing: DesignSystem.Spacing.md) {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(entry.isOverdue ? Color.vendaOchreLt : Color.vendaEmberLt)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text(String(entry.customerName.prefix(1)).uppercased())
                            .font(DesignSystem.Typography.h4)
                            .foregroundColor(entry.isOverdue ? .vendaOchreDk : .vendaEmberDk)
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(entry.customerName)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(.vendaInk)

                    if let phone = entry.customerPhone, !phone.isEmpty {
                        Text(phone)
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(.vendaInkMid)
                    } else {
                        Text("Opened \(entry.lastTransaction.formatted(date: .abbreviated, time: .omitted))")
                            .font(DesignSystem.Typography.captionSmall)
                            .foregroundColor(.vendaInkMid)
                    }

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        CreditStatusBadge(status: entry.status, isOverdue: entry.isOverdue)
                        if let dueDate = entry.dueDate {
                            Text("Due \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(DesignSystem.Typography.captionSmall)
                                .foregroundColor(.vendaInkLt)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                    Text(entry.amountOwed.asZMW())
                        .font(DesignSystem.Typography.bodySemibold)
                        .foregroundColor(entry.isOverdue ? .vendaOchreDk : .vendaEmberDk)
                    Text("\(entry.repaidAmount.asZMW()) repaid")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                }

                if entry.amountOwed > 0 {
                    Menu {
                        Button("Record repayment") { onRepay() }
                        Button("Mark settled") { onSettle() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.vendaInkLt)
                    }
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.vendaForest)
                }
            }
        }
    }
}

private struct ReconciliationStatusBadge: View {
    let status: String

    var body: some View {
        Text(status)
            .font(.system(size: 10, weight: .semibold, design: .default))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(999)
    }

    private var backgroundColor: Color {
        switch status.lowercased() {
        case "matched": return .vendaForestLt
        case "pending": return .vendaOchreLt
        case "unmatched": return .vendaEmberLt
        default: return .vendaParchment
        }
    }

    private var textColor: Color {
        switch status.lowercased() {
        case "matched": return .vendaForestDk
        case "pending": return .vendaOchreDk
        case "unmatched": return .vendaEmberDk
        default: return .vendaInk
        }
    }
}

private struct CreditStatusBadge: View {
    let status: String
    let isOverdue: Bool

    var body: some View {
        Text(isOverdue ? "Overdue" : status.capitalized)
            .font(.system(size: 9, weight: .bold, design: .default))
            .foregroundColor(isOverdue ? .vendaOchreDk : .vendaEmberDk)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isOverdue ? Color.vendaOchreLt : Color.vendaEmberLt)
            .cornerRadius(999)
    }
}

private struct AddMoMoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reference = ""
    @State private var senderPhone = ""
    @State private var amountText = ""

    let onSave: (String, String, Decimal) -> Void

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !senderPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Payment details") {
                    TextField("Reference", text: $reference)
                    TextField("Sender phone", text: $senderPhone)
                        .keyboardType(.phonePad)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Log MoMo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        onSave(
                            reference.trimmingCharacters(in: .whitespacesAndNewlines),
                            senderPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                            amount
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct MatchTransactionSheet: View {
    let transaction: MoMoTransactionSummary
    let sales: [SaleSummary]
    let onMatch: (UUID?) -> Void
    let onStatusChange: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(transaction.reference)
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        Text("\(transaction.senderPhone) • \(transaction.amount.asZMW())")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }
                }

                if sales.isEmpty {
                    Section {
                        Text("No local sales are available to match against yet.")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }
                } else {
                    Section("Match to sale") {
                        ForEach(sales) { sale in
                            Button {
                                onMatch(sale.id)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(sale.reference)
                                            .font(.system(size: 13, weight: .semibold, design: .default))
                                            .foregroundColor(.vendaInk)
                                        Text("\(sale.staffName) • \(sale.timestamp.formatted(date: .abbreviated, time: .shortened))")
                                            .font(.system(size: 11, weight: .regular, design: .default))
                                            .foregroundColor(.vendaInkMid)
                                    }
                                    Spacer()
                                    Text(sale.amount.asZMW())
                                        .font(.system(size: 13, weight: .semibold, design: .default))
                                        .foregroundColor(.vendaForestDk)
                                }
                            }
                        }
                    }
                }

                Section("Status only") {
                    Button("Mark pending") {
                        onStatusChange("pending")
                        dismiss()
                    }
                    Button("Mark unmatched") {
                        onStatusChange("unmatched")
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reconcile Payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct AddCreditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var customerName = ""
    @State private var customerPhone = ""
    @State private var amountText = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(60 * 60 * 24 * 7)

    let onSave: (String, String?, Decimal, Date?) -> Void

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        !customerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Customer") {
                    TextField("Customer name", text: $customerName)
                    TextField("Phone (optional)", text: $customerPhone)
                        .keyboardType(.phonePad)
                }

                Section("Balance") {
                    TextField("Amount owed", text: $amountText)
                        .keyboardType(.decimalPad)
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Record Credit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        onSave(
                            customerName.trimmingCharacters(in: .whitespacesAndNewlines),
                            customerPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : customerPhone.trimmingCharacters(in: .whitespacesAndNewlines),
                            amount,
                            hasDueDate ? dueDate : nil
                        )
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

private struct RecordRepaymentSheet: View {
    let entry: CreditEntrySummary
    let onSave: (Decimal) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""

    private var parsedAmount: Decimal? {
        Decimal(string: amountText.replacingOccurrences(of: ",", with: "."))
    }

    private var canSave: Bool {
        guard let parsedAmount else { return false }
        return parsedAmount > 0 && parsedAmount <= entry.amountOwed
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Balance") {
                    HStack {
                        Text("Outstanding")
                        Spacer()
                        Text(entry.amountOwed.asZMW())
                            .foregroundColor(.vendaInkMid)
                    }
                    HStack {
                        Text("Already repaid")
                        Spacer()
                        Text(entry.repaidAmount.asZMW())
                            .foregroundColor(.vendaInkMid)
                    }
                }

                Section("Repayment") {
                    TextField("Amount received", text: $amountText)
                        .keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Record Repayment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else { return }
                        onSave(amount)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}

#Preview {
    MoneyScreen(viewModel: MoneyViewModel())
}

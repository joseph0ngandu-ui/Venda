import SwiftUI

struct SellScreen: View {
    @ObservedObject var viewModel: SaleViewModel
    @ObservedObject var stockViewModel: StockViewModel
    @State private var showPriceEntry = false
    @State private var showManualItemSheet = false
    @State private var selectedProduct: ProductModel?
    @State private var showPaymentSelection = false
    @State private var showSaleCompletion = false
    @State private var searchText = ""

    private var filteredProducts: [ProductModel] {
        if searchText.isEmpty {
            return stockViewModel.products
        }
        return stockViewModel.products.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Point of Sale")
                            .font(DesignSystem.Typography.h2)
                            .foregroundColor(.vendaInk)
                        Text("Search products, add to cart, and checkout quickly.")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInkMid)
                    }

                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                        GridItem(.flexible(), spacing: DesignSystem.Spacing.md),
                        GridItem(.flexible(), spacing: DesignSystem.Spacing.md)
                    ], spacing: DesignSystem.Spacing.md) {
                        ScreenMetricCard(
                            label: "Products",
                            value: "\(stockViewModel.products.count)",
                            detail: "Ready to sell",
                            icon: "shippingbox",
                            tint: .vendaForest
                        )
                        ScreenMetricCard(
                            label: "In cart",
                            value: "\(viewModel.cartItems.count)",
                            detail: "Queued items",
                            icon: "cart",
                            tint: .vendaOchre
                        )
                        ScreenMetricCard(
                            label: "Checkout",
                            value: viewModel.cartTotal().asZMW(),
                            detail: "Current total",
                            icon: "arrow.right.circle",
                            tint: .vendaEmber
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)

                SearchField(text: $searchText, placeholder: "Search products")
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)

                if filteredProducts.isEmpty {
                    ScrollView {
                        VStack(spacing: 14) {
                            EmptyStateCard(
                                icon: stockViewModel.products.isEmpty ? "shippingbox" : "magnifyingglass",
                                title: stockViewModel.products.isEmpty ? "No products ready yet" : "No matching products",
                                message: stockViewModel.products.isEmpty
                                    ? "Add products in Stock or create a manual item for walk-in sales."
                                    : "Try a different search or add a manual item if you need to keep selling."
                            )

                            ManualItemCard {
                                showManualItemSheet = true
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            ForEach(filteredProducts) { product in
                                ProductCard(product: product) {
                                    selectedProduct = product
                                    showPriceEntry = true
                                }
                            }

                            ManualItemCard {
                                showManualItemSheet = true
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }

                if !viewModel.cartItems.isEmpty {
                    CartSummaryBar(viewModel: viewModel, onCheckout: {
                        showPaymentSelection = true
                    })
                }
            }

            if showPriceEntry, let product = selectedProduct {
                PriceEntrySheet(
                    product: product,
                    isPresented: $showPriceEntry,
                    onAdd: { finalPrice, qty in
                        viewModel.addToCart(product: product, quantity: qty, finalPrice: finalPrice)
                    }
                )
            }

            if showPaymentSelection {
                PaymentSelectionSheet(
                    isPresented: $showPaymentSelection,
                    total: viewModel.cartTotal(),
                    onSelect: { method in
                        viewModel.selectedPaymentMethod = method
                        viewModel.completeSale()
                        showSaleCompletion = true
                    }
                )
            }

            if showSaleCompletion {
                SaleCompletionView(
                    reference: viewModel.currentSaleReference,
                    total: viewModel.lastCompletedTotal,
                    isPresented: $showSaleCompletion
                )
            }

            if showManualItemSheet {
                ManualItemSheet(
                    isPresented: $showManualItemSheet,
                    onAdd: { name, category, price, quantity in
                        let item = ProductModel(
                            name: name,
                            category: category.isEmpty ? "Custom item" : category,
                            pricingType: .open,
                            isService: false
                        )
                        viewModel.addToCart(product: item, quantity: quantity, finalPrice: price)
                    }
                )
            }
        }
    }
}

private struct EmptyProductView: View {
    let hasProducts: Bool

    var body: some View {
        EmptyStateCard(
            icon: hasProducts ? "magnifyingglass" : "shippingbox",
            title: hasProducts ? "No matching products" : "Add your products and services",
            message: hasProducts ? "Try another search or create a manual item for this sale." : "Tap Stock to add items or create a manual item from the sale screen."
        )
        .padding(.horizontal, 16)
    }
}

private struct ProductCard: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VendaCard(accentColor: product.isService ? .vendaOchre : .vendaForest) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(product.isService ? Color.vendaOchreLt : Color.vendaForestLt)
                            .frame(width: 34, height: 34)
                            .overlay(
                                Image(systemName: product.isService ? "briefcase.fill" : "shippingbox.fill")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(product.isService ? .vendaOchreDk : .vendaForestDk)
                            )
                        Spacer()
                        Text(product.pricingType.rawValue.capitalized)
                            .font(.system(size: 9, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInkMid)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.vendaParchment)
                            .cornerRadius(999)
                    }

                    Text(product.name)
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                        .lineLimit(2)

                    Text(product.category)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    PriceDisplay(product: product)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, minHeight: 148, alignment: .leading)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ManualItemCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VendaCard(accentColor: .vendaOchre) {
                VStack(alignment: .center, spacing: 10) {
                    Circle()
                        .fill(Color.vendaOchreLt)
                        .frame(width: 34, height: 34)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.vendaOchreDk)
                        )

                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.vendaInk)

                    Text("Manual item")
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)

                    Text("Add something not yet in stock")
                        .font(.system(size: 10, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .frame(minHeight: 148)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct CartSummaryBar: View {
    @ObservedObject var viewModel: SaleViewModel
    let onCheckout: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.cartItems.count) item(s)")
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.vendaInkLt)
                    Text(viewModel.cartTotal().asZMW())
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                }

                Spacer()

                VendaButton(title: "Checkout", action: onCheckout)
                    .frame(width: 120)
            }
            .padding(16)
            .background(Color.vendaWhite)
        }
        .overlay(
            Divider()
                .foregroundColor(.vendaLine),
            alignment: .top
        )
    }
}

private struct PaymentSelectionSheet: View {
    @Binding var isPresented: Bool
    let total: Decimal
    var onSelect: (String) -> Void
    @State private var selectedMethod = "Cash"

    let methods = ["Cash", "MTN MoMo", "Airtel Money", "Bank Transfer", "Credit"]

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.vendaLine)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                ScreenSectionHeader(title: "Payment method", subtitle: "Choose how this sale will be recorded")
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(methods, id: \.self) { method in
                    PaymentMethodOption(
                        method: method,
                        isSelected: selectedMethod == method,
                        onTap: { selectedMethod = method }
                    )
                }

                VendaButton(
                    title: "Complete sale",
                    action: { onSelect(selectedMethod); isPresented = false }
                )

                Text("You can review and reconcile this sale in Money after checkout.")
                    .font(.system(size: 11, weight: .regular, design: .default))
                    .foregroundColor(.vendaInkLt)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .background(Color.vendaWhite)
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea()
    }
}

private struct PaymentMethodOption: View {
    let method: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack {
                Image(systemName: iconName(for: method))
                    .foregroundColor(.vendaInk)
                Text(method)
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(.vendaInk)
                Spacer()
                Circle()
                    .stroke(isSelected ? Color.vendaForest : Color.vendaLine, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.vendaForest : .clear)
                    )
                    .frame(width: 20, height: 20)
            }
            .padding(12)
            .background(isSelected ? Color.vendaForestLt : Color.vendaParchment)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.vendaForest : Color.clear, lineWidth: 1)
            )
        }
    }

    private func iconName(for method: String) -> String {
        switch method {
        case "Cash": return "banknote"
        case "MTN MoMo": return "phone"
        case "Airtel Money": return "phone.fill"
        case "Bank Transfer": return "building.2"
        case "Credit": return "dollarsign.circle"
        default: return "creditcard"
        }
    }
}

private struct SaleCompletionView: View {
    let reference: String
    let total: Decimal
    @Binding var isPresented: Bool
    @State private var showCheckmark = false

    var body: some View {
        ZStack {
            Color.vendaForest
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                if showCheckmark {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64, weight: .light))
                        .foregroundColor(.white)
                        .transition(.scale.combined(with: .opacity))
                }

                Text("Sale recorded")
                    .font(.system(size: 28, weight: .semibold, design: .default))
                    .foregroundColor(.white)

                SaleReferenceView(reference: reference)
                    .padding(12)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(8)

                Text(total.asZMW())
                    .font(.system(size: 40, weight: .semibold, design: .default))
                    .foregroundColor(.white)

                Spacer()

                VendaButton(
                    title: "New sale",
                    action: { isPresented = false },
                    style: .ghost
                )
            }
            .padding(20)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                showCheckmark = true
            }
        }
    }
}

private struct ManualItemSheet: View {
    @Binding var isPresented: Bool
    var onAdd: (String, String, Decimal, Decimal) -> Void

    @State private var name = ""
    @State private var category = ""
    @State private var price: Decimal = 0
    @State private var quantity: Decimal = 1

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && price > 0
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.vendaLine)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                ScreenSectionHeader(
                    title: "Manual item",
                    subtitle: "Add a one-off product or service to this sale"
                )
                .frame(maxWidth: .infinity, alignment: .leading)

                SheetField(title: "Item name", placeholder: "e.g. Braids touch-up", text: $name)
                SheetField(title: "Category", placeholder: "e.g. Services", text: $category)
                SheetField(title: "Price", placeholder: "0.00", value: $price)

                HStack {
                    Text("Quantity")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.vendaInkMid)
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if quantity > 1 { quantity -= 1 }
                        } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.vendaInk)
                                .frame(width: 32, height: 32)
                                .background(Color.vendaParchment)
                                .cornerRadius(10)
                        }

                        Text(quantity.formatted())
                            .font(.system(size: 15, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                            .frame(minWidth: 28)

                        Button {
                            quantity += 1
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.vendaInk)
                                .frame(width: 32, height: 32)
                                .background(Color.vendaParchment)
                                .cornerRadius(10)
                        }
                    }
                }

                VendaButton(
                    title: "Add to cart",
                    action: {
                        onAdd(name, category, price, quantity)
                        isPresented = false
                    },
                    isEnabled: canAdd
                )
            }
            .padding(20)
            .background(Color.vendaWhite)
            .cornerRadius(20, corners: [.topLeft, .topRight])
        }
        .ignoresSafeArea()
    }
}

private struct SheetField: View {
    let title: String
    let placeholder: String
    var text: Binding<String>? = nil
    var value: Binding<Decimal>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .default))
                .foregroundColor(.vendaInkMid)

            if let text {
                TextField(placeholder, text: text)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.vendaInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.vendaParchment)
                    .cornerRadius(10)
            } else if let value {
                TextField(placeholder, value: value, format: .number)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.vendaInk)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.vendaParchment)
                    .cornerRadius(10)
            }
        }
    }
}

// Custom corner radius modifier
private struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

private extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

#Preview {
    let saleVM = SaleViewModel()
    let stockVM = StockViewModel()
    stockVM.products = [
        ProductModel(name: "Haircut", category: "Services", pricingType: .fixed, suggestedPrice: 150),
        ProductModel(name: "Blow dry", category: "Services", pricingType: .flexible, suggestedPrice: 100),
    ]
    return SellScreen(viewModel: saleVM, stockViewModel: stockVM)
}

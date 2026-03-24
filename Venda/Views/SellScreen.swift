import SwiftUI

struct SellScreen: View {
    @ObservedObject var viewModel: SaleViewModel
    @ObservedObject var stockViewModel: StockViewModel
    @State private var showPriceEntry = false
    @State private var selectedProduct: ProductModel?
    @State private var showPaymentSelection = false
    @State private var showSaleCompletion = false
    @State private var enteredPrice: Decimal = 0
    @State private var quantity: Decimal = 1
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
                // Header
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Point of Sale")
                                .font(.system(size: 22, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInk)
                            Text("\(stockViewModel.products.count) products available")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.vendaInkMid)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.vendaInkLt)
                    TextField("Search products", text: $searchText)
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.vendaInk)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.vendaInkLt)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.vendaWhite)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.vendaLine, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                // Products grid
                if filteredProducts.isEmpty {
                    Spacer()
                    EmptyProductView(hasProducts: !stockViewModel.products.isEmpty)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                            ForEach(filteredProducts) { product in
                                ProductCard(product: product) {
                                    selectedProduct = product
                                    showPriceEntry = true
                                }
                            }

                            CustomItemCard {
                                print("Custom item tapped")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }

                // Cart summary
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
                        enteredPrice = 0
                        quantity = 1
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
                    total: viewModel.cartTotal(),
                    isPresented: $showSaleCompletion
                )
            }
        }
    }
}

private struct EmptyProductView: View {
    let hasProducts: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: hasProducts ? "magnifyingglass" : "shippingbox")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.vendaInkLt)
            Text(hasProducts ? "No matching products" : "Add your products and services")
                .font(.system(size: 15, weight: .medium, design: .default))
                .foregroundColor(.vendaInkMid)
            if !hasProducts {
                Text("Tap the Stock tab to add your first product")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.vendaInkLt)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProductCard: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VendaCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "square.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.vendaForest)
                        Spacer()
                    }

                    Text(product.name)
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                        .lineLimit(2)

                    Spacer()

                    PriceDisplay(product: product)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct CustomItemCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VendaCard {
                VStack(alignment: .center, spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.vendaForest)

                    Text("Custom item")
                        .font(.system(size: 13, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            Divider()
                .foregroundColor(.vendaLine)

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
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.vendaLine)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Text("Payment method")
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.vendaInk)
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
            .background(Color.vendaParchment)
            .cornerRadius(10)
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

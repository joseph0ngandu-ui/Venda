import SwiftUI

struct StockScreen: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: StockViewModel
    @State private var showAddProduct = false
    @State private var selectedProduct: ProductModel?
    @State private var searchText = ""

    var filteredProducts: [ProductModel] {
        if searchText.isEmpty {
            return viewModel.products
        }
        return viewModel.products.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Inventory")
                            .font(DesignSystem.Typography.h3)
                            .foregroundColor(.vendaInk)
                        Text("\(viewModel.products.count) products")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInkMid)
                    }
                    Spacer()
                    if appState.currentUser?.role.isAdminOrManager == true {
                        Button(action: { showAddProduct = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: DesignSystem.ComponentSize.iconMedium, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: DesignSystem.ComponentSize.avatarSmall, height: DesignSystem.ComponentSize.avatarSmall)
                                .background(Color.vendaForest)
                                .cornerRadius(DesignSystem.Radius.md)
                        }
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.md)

                SearchField(text: $searchText, placeholder: "Search products")
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.md)

                // List
                if filteredProducts.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: searchText.isEmpty ? "shippingbox" : "magnifyingglass")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.vendaInkLt)
                        Text(searchText.isEmpty ? "No products yet" : "No matching products")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.vendaInkMid)
                        if searchText.isEmpty {
                            Text("Tap + to add your first product")
                                .font(.system(size: 12, weight: .regular, design: .default))
                                .foregroundColor(.vendaInkLt)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(filteredProducts) { product in
                                ProductListRow(product: product) {
                                    selectedProduct = product
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }

            if showAddProduct {
                AddProductSheet(
                    isPresented: $showAddProduct,
                    stockViewModel: viewModel
                )
            }
        }
    }
}

private struct ProductListRow: View {
    let product: ProductModel
    let onTap: () -> Void

    var body: some View {
        VendaCard {
            HStack(spacing: 12) {
                Image(systemName: "square.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.vendaForest)
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(product.name)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(product.category)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    PriceDisplay(product: product)
                    Text(product.pricingType.rawValue.capitalized)
                        .font(.system(size: 9, weight: .medium, design: .default))
                        .foregroundColor(.vendaInkLt)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct AddProductSheet: View {
    @Binding var isPresented: Bool
    let stockViewModel: StockViewModel
    @State private var name = ""
    @State private var category = ""
    @State private var selectedPricingType = PricingType.fixed
    @State private var suggestedPrice: Decimal = 0
    @State private var minPrice: Decimal = 0
    @State private var maxPrice: Decimal = 0
    @State private var isService = false

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

                HStack {
                    Text("Add product")
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.vendaInkMid)
                            .frame(width: 28, height: 28)
                            .background(Color.vendaParchment)
                            .cornerRadius(14)
                    }
                }

                VStack(spacing: DesignSystem.Spacing.md) {
                    VendaTextField(label: nil, placeholder: "Product name", text: $name)
                    VendaTextField(label: nil, placeholder: "Category", text: $category)
                }

                Text("Pricing type")
                    .font(.system(size: 12, weight: .semibold, design: .default))
                    .foregroundColor(.vendaInkLt)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PricingTypePicker(selectedType: $selectedPricingType)

                switch selectedPricingType {
                case .fixed:
                    VendaNumberField(label: nil, placeholder: "Price", value: $suggestedPrice)
                case .flexible:
                    VendaNumberField(label: nil, placeholder: "Suggested price", value: $suggestedPrice)
                case .range:
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        VendaNumberField(label: nil, placeholder: "Min price", value: $minPrice)
                        VendaNumberField(label: nil, placeholder: "Max price", value: $maxPrice)
                    }
                case .open, .service:
                    EmptyView()
                }

                VendaButton(
                    title: "Add product",
                    action: {
                        let product = ProductModel(
                            name: name,
                            category: category,
                            pricingType: selectedPricingType,
                            suggestedPrice: suggestedPrice > 0 ? suggestedPrice : nil,
                            minPrice: minPrice > 0 ? minPrice : nil,
                            maxPrice: maxPrice > 0 ? maxPrice : nil,
                            isService: isService
                        )
                        stockViewModel.addProduct(product)
                        isPresented = false
                    },
                    isEnabled: !name.isEmpty
                )

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 50)
            .background(Color.vendaWhite)
            .cornerRadius(20)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    let viewModel = StockViewModel()
    viewModel.products = [
        ProductModel(name: "Haircut", category: "Services", pricingType: .fixed, suggestedPrice: 150),
        ProductModel(name: "Blow dry", category: "Services", pricingType: .flexible, suggestedPrice: 100),
    ]
    return StockScreen(viewModel: viewModel)
        .environmentObject(AppState())
}

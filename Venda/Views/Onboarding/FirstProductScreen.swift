import SwiftUI

struct FirstProductScreen: View {
    var onComplete: (ProductModel?) -> Void
    var onSkip: () -> Void

    @State private var name = ""
    @State private var category = ""
    @State private var selectedPricingType = PricingType.fixed
    @State private var suggestedPrice: Decimal = 0
    @State private var minPrice: Decimal = 0
    @State private var maxPrice: Decimal = 0
    @State private var isService = false

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    ProgressDot(isActive: true)
                    ProgressDot(isActive: true)
                    ProgressDot(isActive: true)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Add your first item")
                                .font(.system(size: 24, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInk)
                            Text("Start building your inventory. You can add more later.")
                                .font(.system(size: 15, weight: .regular, design: .default))
                                .foregroundColor(.vendaInkMid)
                        }

                        VStack(spacing: 16) {
                            // Product Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Item Name")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Wash and Set", text: $name)
                                    .padding(16)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            // Category
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Haircare", text: $category)
                                    .padding(16)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
                            }
                        }

                        // Pricing Type
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Pricing Strategy")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInkLt)
                            
                            PricingTypePicker(selectedType: $selectedPricingType)
                                .padding(.horizontal, -20) // Bleed to edges
                        }

                        // Price Input
                        VStack(alignment: .leading, spacing: 8) {
                            switch selectedPricingType {
                            case .fixed:
                                InputField(label: "Selling Price", value: $suggestedPrice)
                            case .flexible:
                                InputField(label: "Suggested Price", value: $suggestedPrice)
                            case .range:
                                HStack(spacing: 16) {
                                    InputField(label: "Minimum Price", value: $minPrice)
                                    InputField(label: "Maximum Price", value: $maxPrice)
                                }
                            case .open, .service:
                                Text("Price will be entered at checkout.")
                                    .font(.system(size: 14, weight: .medium, design: .default))
                                    .foregroundColor(.vendaInkMid)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }

                VStack(spacing: 16) {
                    VendaButton(
                        title: "Add Item & Finish",
                        action: {
                            let product = ProductModel(
                                name: name,
                                category: category.isEmpty ? "Uncategorized" : category,
                                pricingType: selectedPricingType,
                                suggestedPrice: suggestedPrice > 0 ? suggestedPrice : nil,
                                minPrice: minPrice > 0 ? minPrice : nil,
                                maxPrice: maxPrice > 0 ? maxPrice : nil,
                                isService: selectedPricingType == .service
                            )
                            onComplete(product)
                        },
                        isEnabled: !name.isEmpty
                    )

                    Button(action: onSkip) {
                        Text("Skip for now")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.vendaInkMid)
                            .frame(height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct ProgressDot: View {
    let isActive: Bool
    var body: some View {
        Circle()
            .fill(isActive ? Color.vendaForest : Color.vendaLine)
            .frame(width: 8, height: 8)
    }
}

private struct InputField: View {
    let label: String
    var value: Binding<Decimal>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(.vendaInkLt)
            
            HStack(spacing: 8) {
                Text("K")
                    .font(.system(size: 15, weight: .medium, design: .default))
                    .foregroundColor(.vendaInkLt)
                TextField("0.00", value: value, format: .number)
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundColor(.vendaInk)
                    .keyboardType(.decimalPad)
            }
            .padding(16)
            .background(Color.vendaWhite)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
        }
    }
}

#Preview {
    FirstProductScreen(onComplete: { _ in }, onSkip: {})
}

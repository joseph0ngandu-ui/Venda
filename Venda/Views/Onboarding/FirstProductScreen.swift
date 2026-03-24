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
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.xl)

                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Add your first item")
                                .font(DesignSystem.Typography.h2)
                                .foregroundColor(.vendaInk)
                            Text("Start building your inventory. You can add more later.")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.vendaInkMid)
                        }

                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Product Name
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Item Name")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Wash and Set", text: $name)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(DesignSystem.Radius.md)
                                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            // Category
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Category")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Haircare", text: $category)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(DesignSystem.Radius.md)
                                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
                            }
                        }

                        // Pricing Type
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Pricing Strategy")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(.vendaInkLt)
                            
                            PricingTypePicker(selectedType: $selectedPricingType)
                                .padding(.horizontal, -DesignSystem.Spacing.lg) // Bleed to edges
                        }

                        // Price Input
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            switch selectedPricingType {
                            case .fixed:
                                InputField(label: "Selling Price", value: $suggestedPrice)
                            case .flexible:
                                InputField(label: "Suggested Price", value: $suggestedPrice)
                            case .range:
                                HStack(spacing: DesignSystem.Spacing.lg) {
                                    InputField(label: "Minimum Price", value: $minPrice)
                                    InputField(label: "Maximum Price", value: $maxPrice)
                                }
                            case .open, .service:
                                Text("Price will be entered at checkout.")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(.vendaInkMid)
                                    .padding(.vertical, DesignSystem.Spacing.sm)
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxxl)
                }

                VStack(spacing: DesignSystem.Spacing.lg) {
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
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.vendaInkMid)
                            .frame(height: DesignSystem.ComponentSize.buttonHeightSmall)
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
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
            .frame(width: DesignSystem.ComponentSize.progressDotSize, height: DesignSystem.ComponentSize.progressDotSize)
    }
}

private struct InputField: View {
    let label: String
    var value: Binding<Decimal>

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(DesignSystem.Typography.label)
                .foregroundColor(.vendaInkLt)
            
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("K")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.vendaInkLt)
                TextField("0.00", value: value, format: .number)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(.vendaInk)
                    .keyboardType(.decimalPad)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
        }
    }
}

#Preview {
    FirstProductScreen(onComplete: { _ in }, onSkip: {})
}

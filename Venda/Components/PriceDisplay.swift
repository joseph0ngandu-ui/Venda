import SwiftUI

struct PriceDisplay: View {
    let product: ProductModel

    var body: some View {
        switch product.pricingType {
        case .fixed:
            if let price = product.suggestedPrice {
                Text(price.asZMW())
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.vendaInk)
            }

        case .flexible:
            HStack(spacing: 4) {
                if let price = product.suggestedPrice {
                    Text(price.asZMW())
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.vendaOchre)
                }
                Text("flex")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundColor(.vendaOchreDk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.vendaOchreLt)
                    .cornerRadius(4)
            }

        case .range:
            if let minPrice = product.minPrice, let maxPrice = product.maxPrice {
                Text("\(minPrice.asZMW())–\(maxPrice.asZMW())")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.vendaInkMid)
            }

        case .open:
            Text("Set price")
                .font(.system(size: 13, weight: .regular, design: .default))
                .italic()
                .foregroundColor(.vendaInkLt)

        case .service:
            Text("Service")
                .font(.system(size: 10, weight: .medium, design: .default))
                .foregroundColor(.vendaForestDk)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.vendaForestLt)
                .cornerRadius(4)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        PriceDisplay(product: ProductModel(name: "Fixed", category: "test", pricingType: .fixed, suggestedPrice: 150))
        PriceDisplay(product: ProductModel(name: "Flexible", category: "test", pricingType: .flexible, suggestedPrice: 200))
        PriceDisplay(product: ProductModel(name: "Range", category: "test", pricingType: .range, minPrice: 100, maxPrice: 300))
        PriceDisplay(product: ProductModel(name: "Open", category: "test", pricingType: .open))
        PriceDisplay(product: ProductModel(name: "Service", category: "test", pricingType: .service, isService: true))
    }
    .padding()
}

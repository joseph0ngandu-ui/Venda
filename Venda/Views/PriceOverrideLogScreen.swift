import SwiftUI

struct PriceOverrideLogScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel = PriceOverrideViewModel()
    
    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
                        Text("Price Overrides")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        Text("Audit Log")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }
                    Spacer()
                    // Dummy spacer for balance
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                if viewModel.overrides.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "shield.checkerboard")
                            .font(.system(size: 36, weight: .light))
                            .foregroundColor(.vendaForest.opacity(0.5))
                        Text("No price overrides detected")
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.vendaInkMid)
                        Text("Staff haven't overridden any prices yet.")
                            .font(.system(size: 13, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkLt)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.overrides) { log in
                                OverrideLogRow(log: log)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.fetchOverrides()
        }
    }
}

// Model & ViewModel
struct PriceOverrideLog: Identifiable {
    let id: UUID
    let productName: String
    let staffName: String
    let originalPrice: Decimal
    let finalPrice: Decimal
    let timestamp: Date
    let reference: String
    
    var discountAmount: Decimal {
        originalPrice - finalPrice
    }
}

@MainActor
final class PriceOverrideViewModel: ObservableObject {
    @Published var overrides: [PriceOverrideLog] = []
    
    func fetchOverrides() {
        // Mock data for UI layout - this will integrate with CoreData SaleLineItems
        // where originalPrice != finalPrice
        overrides = [
            PriceOverrideLog(
                id: UUID(),
                productName: "Premium Braids",
                staffName: "Chanda",
                originalPrice: 200,
                finalPrice: 150,
                timestamp: Date().addingTimeInterval(-3600),
                reference: "VND-1804"
            ),
            PriceOverrideLog(
                id: UUID(),
                productName: "Latte Macchiato",
                staffName: "Kasela",
                originalPrice: 45,
                finalPrice: 40,
                timestamp: Date().addingTimeInterval(-86400),
                reference: "VND-1801"
            )
        ]
    }
}

private struct OverrideLogRow: View {
    let log: PriceOverrideLog
    
    var body: some View {
        VendaCard {
            VStack(alignment: .leading, spacing: 12) {
                // Header (Staff & time)
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.vendaEmber.opacity(0.1))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.vendaEmber)
                            )
                        
                        Text(log.staffName)
                            .font(.system(size: 12, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                    }
                    
                    Spacer()
                    
                    Text("\(log.reference) • \(log.timestamp.asVendaTime())")
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }
                
                Divider()
                    .foregroundColor(.vendaLine)
                    
                // Product & Pricing Action
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(log.productName)
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(.vendaInk)
                        
                        Text("Discounted by \(log.discountAmount.asZMW())")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.vendaEmber)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(log.originalPrice.asZMW())
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .strikethrough()
                            .foregroundColor(.vendaInkLt)
                        Text(log.finalPrice.asZMW())
                            .font(.system(size: 15, weight: .bold, design: .default))
                            .foregroundColor(.vendaInk)
                    }
                }
            }
        }
    }
}

#Preview {
    PriceOverrideLogScreen()
}

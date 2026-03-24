import SwiftUI

struct PriceEntrySheet: View {
    let product: ProductModel
    @Binding var isPresented: Bool
    var onAdd: (Decimal, Decimal) -> Void
    
    // Internal state
    @State private var quantity: Decimal = 1
    @State private var keyboardInput: String = ""
    @State private var isDiscountMode: Bool = false
    @State private var discountType: DiscountType = .amount // .amount or .percent
    
    enum DiscountType {
        case amount
        case percent
    }
    
    var originalPrice: Decimal {
        return product.suggestedPrice ?? 0
    }
    
    var showDiscountToggle: Bool {
        // Only show discount toggle if the product has a fixed/suggested price
        return product.pricingType == .fixed || (product.pricingType == .flexible && product.suggestedPrice != nil)
    }
    
    var computedPrice: Decimal {
        let inputVal = Decimal(string: keyboardInput) ?? 0
        
        if showDiscountToggle {
            if isDiscountMode {
                if discountType == .amount {
                    return max(0, originalPrice - inputVal)
                } else {
                    let discountAmount = originalPrice * (inputVal / 100)
                    return max(0, originalPrice - discountAmount)
                }
            } else {
                // If they are explicitly typing a new manual price despite knowing the original (override)
                return keyboardInput.isEmpty ? originalPrice : inputVal
            }
        } else {
            // Open pricing / service with no suggested price
            return inputVal
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
                
            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.vendaLine)
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        if showDiscountToggle {
                            Text("Original price: \(originalPrice.asZMW())")
                                .font(.system(size: 13, weight: .regular, design: .default))
                                .foregroundColor(.vendaInkMid)
                        }
                    }
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
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                // Display Area
                VStack(spacing: 8) {
                    if showDiscountToggle {
                        // Discount Mode Toggle
                        HStack(spacing: 0) {
                            Button(action: { 
                                isDiscountMode = false
                                keyboardInput = "" 
                            }) {
                                Text("Set Price")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(isDiscountMode ? .vendaInkMid : .white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(isDiscountMode ? Color.clear : Color.vendaForest)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: { 
                                isDiscountMode = true
                                keyboardInput = "" 
                            }) {
                                Text("Discount")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(!isDiscountMode ? .vendaInkMid : .vendaEmber)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(!isDiscountMode ? Color.clear : Color.vendaEmber.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(4)
                        .background(Color.vendaParchment)
                        .cornerRadius(10)
                        .padding(.bottom, 12)
                        
                        if isDiscountMode {
                            // Discount type (Amount vs %)
                            Picker("", selection: $discountType) {
                                Text("Amount").tag(DiscountType.amount)
                                Text("Percentage").tag(DiscountType.percent)
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                            .onChange(of: discountType) { _ in keyboardInput = "" }
                        }
                    }
                    
                    // The large typed number
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        if !isDiscountMode || discountType == .amount {
                            Text("K")
                                .font(.system(size: 24, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInkLt)
                        }
                        Text(keyboardInput.isEmpty ? "0" : keyboardInput)
                            .font(.system(size: 48, weight: .bold, design: .default))
                            .foregroundColor(.vendaInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        if isDiscountMode && discountType == .percent {
                            Text("%")
                                .font(.system(size: 24, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInkLt)
                        }
                    }
                    .frame(height: 60)
                    
                    if isDiscountMode || (!isDiscountMode && !keyboardInput.isEmpty) {
                        Text("Final price: \(computedPrice.asZMW())")
                            .font(.system(size: 14, weight: .medium, design: .default))
                            .foregroundColor(isDiscountMode ? .vendaEmber : .vendaForest)
                            .padding(.top, 4)
                    }
                }
                .padding(.bottom, 24)
                
                // Quantity Selector
                HStack {
                    Text("Quantity")
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInkLt)
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: { if quantity > 1 { quantity -= 1 } }) {
                            Image(systemName: "minus")
                                .foregroundColor(.vendaInk)
                                .frame(width: 40, height: 40)
                                .background(Color.vendaSand)
                                .cornerRadius(8)
                        }
                        Text("\(quantity)")
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                            .frame(minWidth: 32, alignment: .center)
                        Button(action: { quantity += 1 }) {
                            Image(systemName: "plus")
                                .foregroundColor(.vendaInk)
                                .frame(width: 40, height: 40)
                                .background(Color.vendaSand)
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                
                // Custom Keypad
                CustomNumericKeypad(input: $keyboardInput)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                
                // Add Button
                VendaButton(title: "Add \(quantity > 1 ? "\(quantity) " : "")to cart", action: {
                    onAdd(computedPrice, quantity)
                    isPresented = false
                })
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.vendaWhite)
            .cornerRadius(24, corners: [.topLeft, .topRight])
        }
    }
}

private struct CustomNumericKeypad: View {
    @Binding var input: String
    
    let rows = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete.left.fill"]
    ]
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 12) {
                    ForEach(row, id: \.self) { prop in
                        Button(action: { handleKeypadPress(prop) }) {
                            if prop == "delete.left.fill" {
                                Image(systemName: prop)
                                    .font(.system(size: 20))
                                    .foregroundColor(.vendaInk)
                            } else {
                                Text(prop)
                                    .font(.system(size: 24, weight: .medium, design: .default))
                                    .foregroundColor(.vendaInk)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.vendaSand)
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private func handleKeypadPress(_ key: String) {
        if key == "delete.left.fill" {
            if !input.isEmpty {
                input.removeLast()
            }
        } else if key == "." {
            if !input.contains(".") {
                input.append(key)
            }
        } else {
            if input == "0" && key != "." {
                input = key
            } else {
                // Limit to 2 decimal places
                if let dotIndex = input.firstIndex(of: ".") {
                    let distance = input.distance(from: dotIndex, to: input.endIndex)
                    if distance <= 2 {
                        input.append(key)
                    }
                } else {
                    // limit total length visually
                    if input.count < 8 {
                        input.append(key)
                    }
                }
            }
        }
    }
}

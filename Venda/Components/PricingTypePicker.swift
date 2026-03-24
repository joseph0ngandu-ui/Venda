import SwiftUI

struct PricingTypePicker: View {
    @Binding var selectedType: PricingType

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(PricingType.allCases, id: \.self) { type in
                    VStack(spacing: 6) {
                        Image(systemName: iconName(for: type))
                            .font(.system(size: 20, weight: .semibold))
                        Text(label(for: type))
                            .font(.system(size: 11, weight: .medium, design: .default))
                    }
                    .frame(width: 88, height: 80)
                    .foregroundColor(selectedType == type ? .vendaForest : .vendaInk)
                    .background(selectedType == type ? Color.vendaForestLt : Color.vendaWhite)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(selectedType == type ? Color.vendaForest : Color.vendaLine, lineWidth: selectedType == type ? 1.5 : 1)
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            selectedType = type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func iconName(for type: PricingType) -> String {
        switch type {
        case .fixed: return "lock.fill"
        case .flexible: return "slider.horizontal.3"
        case .range: return "chart.bar.fill"
        case .open: return "pencil"
        case .service: return "briefcase.fill"
        }
    }

    private func label(for type: PricingType) -> String {
        switch type {
        case .fixed: return "Fixed"
        case .flexible: return "Flexible"
        case .range: return "Range"
        case .open: return "Open"
        case .service: return "Service"
        }
    }
}

private struct PricingTypePickerPreview: View {
    @State private var type: PricingType = .fixed
    var body: some View {
        PricingTypePicker(selectedType: $type)
    }
}

#Preview {
    PricingTypePickerPreview()
}

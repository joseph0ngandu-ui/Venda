import SwiftUI

struct PaymentMethodBadge: View {
    let method: String

    var body: some View {
        Text(method)
            .font(.system(size: 10, weight: .medium, design: .default))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch method.lowercased() {
        case "cash": return .vendaForestLt
        case "mtn momo": return .vendaOchreLt
        case "airtel money": return .vendaEmberLt
        case "credit": return Color.gray.opacity(0.1)
        default: return .vendaParchment
        }
    }

    private var textColor: Color {
        switch method.lowercased() {
        case "cash": return .vendaForestDk
        case "mtn momo": return .vendaOchreDk
        case "airtel money": return .vendaEmberDk
        case "credit": return .vendaInkMid
        default: return .vendaInk
        }
    }
}

#Preview {
    HStack(spacing: 8) {
        PaymentMethodBadge(method: "Cash")
        PaymentMethodBadge(method: "MTN MoMo")
        PaymentMethodBadge(method: "Airtel Money")
        PaymentMethodBadge(method: "Credit")
    }
    .padding()
}

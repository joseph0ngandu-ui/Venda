import SwiftUI

struct VendaCard<Content: View>: View {
    let content: Content
    var accentColor: Color? = nil
    var backgroundColor: Color = .vendaWhite
    var borderColor: Color = .vendaLine

    init(
        accentColor: Color? = nil,
        backgroundColor: Color = .vendaWhite,
        borderColor: Color = .vendaLine,
        @ViewBuilder content: () -> Content
    ) {
        self.accentColor = accentColor
        self.backgroundColor = backgroundColor
        self.borderColor = borderColor
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let accentColor = accentColor {
                RoundedRectangle(cornerRadius: 4)
                    .fill(accentColor)
                    .frame(width: 3)
            }

            content
                .padding(12)
        }
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        VendaCard {
            Text("Default card")
        }
        VendaCard(accentColor: .vendaForest) {
            Text("Card with accent")
        }
    }
    .padding()
    .background(Color.vendaSand)
}

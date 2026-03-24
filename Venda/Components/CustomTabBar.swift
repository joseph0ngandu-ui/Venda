import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: VendaTab

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(VendaTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 17, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 10, weight: .semibold, design: .default))
                        }
                        .foregroundColor(selectedTab == tab ? .vendaForestDk : .vendaInkLt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(selectedTab == tab ? Color.vendaForestLt : Color.clear)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selectedTab == tab ? Color.vendaForest.opacity(0.18) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(10)
            .background(Color.vendaWhite)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(Color.vendaLine, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 10)
        }
        .background(Color.vendaSand)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var tab: VendaTab = .home
        var body: some View {
            CustomTabBar(selectedTab: $tab)
                .preferredColorScheme(.light)
        }
    }
    return PreviewWrapper()
}

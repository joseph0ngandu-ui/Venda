import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: VendaTab

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .foregroundColor(Color.vendaLine)

            HStack(spacing: 0) {
                ForEach(VendaTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 20, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 11, weight: .medium, design: .default))
                        }
                        .foregroundColor(selectedTab == tab ? Color.vendaForest : Color.vendaInkLt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .background(Color.vendaSand)
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


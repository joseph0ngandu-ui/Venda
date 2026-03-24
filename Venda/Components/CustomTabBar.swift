import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: VendaTab

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(VendaTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: DesignSystem.ComponentSize.iconMedium, weight: .semibold))
                            Text(tab.title)
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(selectedTab == tab ? .vendaForestDk : .vendaInkLt)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                        .background(selectedTab == tab ? Color.vendaForestLt : Color.clear)
                        .cornerRadius(DesignSystem.Radius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                                .stroke(
                                    selectedTab == tab ? Color.vendaForest.opacity(0.18) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(tab.title)
                    .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.vendaWhite)
            .cornerRadius(DesignSystem.Radius.xl)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                    .stroke(Color.vendaLine, lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(0.06),
                radius: DesignSystem.Shadow.elevated.radius,
                x: 0,
                y: DesignSystem.Shadow.elevated.y
            )
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md + 8) // Extra padding for safe area
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

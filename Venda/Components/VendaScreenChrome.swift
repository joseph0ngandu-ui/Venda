import SwiftUI

struct ScreenSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(title.uppercased())
                .font(DesignSystem.Typography.caption)
                .tracking(0.9)
                .foregroundColor(.vendaInkLt)

            if let subtitle {
                Text(subtitle)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.vendaInkMid)
            }
        }
    }
}

struct ScreenMetricCard: View {
    let label: String
    let value: String
    var detail: String? = nil
    var icon: String? = nil
    var tint: Color = .vendaForest

    var body: some View {
        VendaCard(accentColor: tint) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(label)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInkLt)
                        Text(value)
                            .font(DesignSystem.Typography.h3)
                            .foregroundColor(.vendaInk)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)

                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: DesignSystem.ComponentSize.iconMedium, weight: .semibold))
                            .foregroundColor(tint)
                            .frame(
                                width: DesignSystem.ComponentSize.avatarSmall,
                                height: DesignSystem.ComponentSize.avatarSmall
                            )
                            .background(tint.opacity(0.12))
                            .cornerRadius(DesignSystem.Radius.sm)
                    }
                }

                if let detail {
                    Text(detail)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                }
            }
        }
    }
}

struct EmptyStateCard: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var actionStyle: VendaButton.ButtonStyle = .ghost
    var action: (() -> Void)? = nil

    var body: some View {
        VendaCard {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Image(systemName: icon)
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.vendaForest)
                    .frame(
                        width: DesignSystem.ComponentSize.avatarLarge,
                        height: DesignSystem.ComponentSize.avatarLarge
                    )
                    .background(Color.vendaForestLt)
                    .cornerRadius(DesignSystem.Radius.lg)

                VStack(spacing: DesignSystem.Spacing.md) {
                    Text(title)
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(.vendaInk)
                    Text(message)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.vendaInkMid)
                        .multilineTextAlignment(.center)
                }

                if let actionTitle = actionTitle, let action = action {
                    VendaButton(
                        title: actionTitle,
                        action: action,
                        style: actionStyle,
                        size: .medium
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Spacing.md)
        }
    }
}

struct ProfileSummaryCard: View {
    let initials: String
    let name: String
    let subtitle: String
    let badgeTitle: String

    var body: some View {
        VendaCard(backgroundColor: .vendaWhite, borderColor: .vendaLine) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Circle()
                    .fill(Color.vendaForest)
                    .frame(
                        width: DesignSystem.ComponentSize.avatarMedium,
                        height: DesignSystem.ComponentSize.avatarMedium
                    )
                    .overlay(
                        Text(initials.uppercased())
                            .font(DesignSystem.Typography.h4)
                            .foregroundColor(.white)
                    )
                    .accessibilityLabel("\(name) avatar")

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(name)
                            .font(DesignSystem.Typography.h4)
                            .foregroundColor(.vendaInk)
                        Text(subtitle)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.vendaInkMid)
                    }

                    Text(badgeTitle)
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaForestDk)
                        .padding(.horizontal, DesignSystem.Spacing.md)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(Color.vendaForestLt)
                        .cornerRadius(DesignSystem.Radius.full)
                }

                Spacer(minLength: 0)
            }
        }
    }
}


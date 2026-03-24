import SwiftUI

struct ScreenSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(0.9)
                .foregroundColor(.vendaInkLt)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular, design: .default))
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.system(size: 11, weight: .medium, design: .default))
                            .foregroundColor(.vendaInkLt)
                        Text(value)
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                    }

                    Spacer()

                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(tint)
                            .frame(width: 28, height: 28)
                            .background(tint.opacity(0.12))
                            .cornerRadius(8)
                    }
                }

                if let detail {
                    Text(detail)
                        .font(.system(size: 10, weight: .regular, design: .default))
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
            VStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 30, weight: .light))
                    .foregroundColor(.vendaForest)
                    .frame(width: 56, height: 56)
                    .background(Color.vendaForestLt)
                    .cornerRadius(16)

                VStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(message)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                        .multilineTextAlignment(.center)
                }

                if let actionTitle, let action {
                    VendaButton(title: actionTitle, action: action, style: actionStyle)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
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
            HStack(spacing: 14) {
                Circle()
                    .fill(Color.vendaForest)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Text(initials.uppercased())
                            .font(.system(size: 16, weight: .bold, design: .default))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                    Text(badgeTitle)
                        .font(.system(size: 10, weight: .semibold, design: .default))
                        .foregroundColor(.vendaForestDk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.vendaForestLt)
                        .cornerRadius(999)
                }

                Spacer(minLength: 0)
            }
        }
    }
}


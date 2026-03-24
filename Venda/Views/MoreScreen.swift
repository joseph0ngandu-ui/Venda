import SwiftUI

struct MoreScreen: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.vendaSand
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(.system(size: 22, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                    ScrollView {
                        VStack(spacing: 24) {
                            // Business section
                            SettingsSection(title: "Business") {
                                SettingsRow(
                                    icon: "chart.bar.fill",
                                    title: "Reports & Analytics",
                                    subtitle: "View sales performance",
                                    destination: AnyView(ReportsScreen())
                                )
                                SettingsRow(
                                    icon: "person.2.fill",
                                    title: "Staff & Roles",
                                    subtitle: "Manage team access",
                                    destination: AnyView(Text("Staff Coming Soon"))
                                )
                            }

                            // Settings section
                            SettingsSection(title: "Settings") {
                                SettingsRow(
                                    icon: "gear",
                                    title: "Account Settings",
                                    subtitle: "Business profile & preferences",
                                    destination: AnyView(Text("Account Coming Soon"))
                                )
                                SettingsRow(
                                    icon: "bell.fill",
                                    title: "Notifications",
                                    subtitle: "Alerts & reminders",
                                    destination: AnyView(Text("Notifications Coming Soon"))
                                )
                                SettingsRow(
                                    icon: "lock.fill",
                                    title: "Security & Audit",
                                    subtitle: "PINs & price overrides",
                                    destination: AnyView(PriceOverrideLogScreen())
                                )
                            }

                            // Support section
                            SettingsSection(title: "Support") {
                                SettingsRow(
                                    icon: "questionmark.circle",
                                    title: "Help & Support",
                                    subtitle: "FAQs & contact us",
                                    destination: AnyView(Text("Support Coming Soon"))
                                )
                                SettingsRow(
                                    icon: "doc.text",
                                    title: "Terms & Privacy",
                                    subtitle: "Legal information",
                                    destination: AnyView(Text("Legal Coming Soon"))
                                )
                            }

                            // App info
                            VStack(spacing: 8) {
                                Image("VendaLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(8)
                                Text("Venda")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInk)
                                Text("Version 1.0.0")
                                    .font(.system(size: 11, weight: .regular, design: .default))
                                    .foregroundColor(.vendaInkLt)
                            }
                            .padding(.vertical, 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold, design: .default))
                .tracking(0.8)
                .foregroundColor(.vendaInkLt)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(Color.vendaWhite)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.vendaLine, lineWidth: 1)
            )
        }
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let destination: AnyView

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.vendaForest)
                    .frame(width: 32, height: 32)
                    .background(Color.vendaForestLt)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium, design: .default))
                        .foregroundColor(.vendaInk)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.vendaInkLt)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MoreScreen()
}

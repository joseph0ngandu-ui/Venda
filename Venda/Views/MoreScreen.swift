import SwiftUI
import UIKit

struct MoreScreen: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject private var syncEngine = SyncEngine.shared
    @State private var showLogoutConfirmation = false

    private var currentUserName: String {
        appState.currentUser?.name ?? "Venda User"
    }

    private var currentUserInitials: String {
        let parts = currentUserName.split(separator: " ")
        let initials = parts.prefix(2).compactMap(\.first)
        return initials.isEmpty ? "V" : String(initials)
    }

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    private var lastSyncLabel: String {
        guard let lastSync = UserDefaults.standard.object(forKey: "venda.last.successful.sync") as? Date else {
            return "No successful sync yet"
        }

        return lastSync.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vendaSand
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack {
                        Text("Settings")
                            .font(DesignSystem.Typography.h3)
                            .foregroundColor(.vendaInk)
                        Spacer()
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.md)
                    .padding(.bottom, DesignSystem.Spacing.lg)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            let isManagerOrAdmin = appState.currentUser?.role.isAdminOrManager ?? false

                            ProfileSummaryCard(
                                initials: currentUserInitials,
                                name: appState.currentUser?.businessName ?? currentUserName,
                                subtitle: "\(appState.currentUser?.companyCode ?? "VND-0000") • \(appState.currentUser?.role.rawValue.capitalized ?? "Staff")",
                                badgeTitle: "Signed in as \(currentUserName)"
                            )

                            OperationalStatusCard(
                                roleTitle: appState.currentUser?.role.rawValue.capitalized ?? "Staff",
                                companyCode: appState.currentUser?.companyCode ?? "VND-0000",
                                lastSyncLabel: lastSyncLabel,
                                isOnline: syncEngine.isOnline,
                                isSyncing: syncEngine.isSyncing
                            )

                            if isManagerOrAdmin {
                                SettingsSection(title: "Business") {
                                    SettingsRow(
                                        icon: "chart.bar.fill",
                                        title: "Reports & Analytics",
                                        subtitle: "Review revenue, payment mix, and top products",
                                        destination: AnyView(ReportsScreen().environmentObject(appState))
                                    )
                                    SettingsRow(
                                        icon: "person.2.fill",
                                        title: "Staff & Roles",
                                        subtitle: "Manage team access, roles, and PIN setup",
                                        destination: AnyView(AdminPanelScreen(appState: appState))
                                    )
                                }
                            }

                            SettingsSection(title: "Settings") {
                                SettingsRow(
                                    icon: "building.2.fill",
                                    title: "Account Settings",
                                    subtitle: "Business profile, company code, and operator details",
                                    destination: AnyView(BusinessProfileScreen(currentUser: appState.currentUser))
                                )
                                SettingsRow(
                                    icon: "bell.badge.fill",
                                    title: "Notifications",
                                    subtitle: "In-app reminders for stock, credit, and sync health",
                                    destination: AnyView(NotificationPreferencesScreen())
                                )

                                if isManagerOrAdmin {
                                    SettingsRow(
                                        icon: "lock.fill",
                                        title: "Security & Audit",
                                        subtitle: "PINs, overrides, and control history",
                                        destination: AnyView(PriceOverrideLogScreen())
                                    )
                                }
                            }

                            SettingsSection(title: "Support") {
                                SettingsRow(
                                    icon: "questionmark.circle.fill",
                                    title: "Help & Support",
                                    subtitle: "Troubleshooting playbooks and operating notes",
                                    destination: AnyView(HelpSupportScreen())
                                )
                                SettingsRow(
                                    icon: "doc.text.fill",
                                    title: "Terms & Privacy",
                                    subtitle: "Data handling summary for this build",
                                    destination: AnyView(LegalSummaryScreen())
                                )
                            }

                            SettingsSection(title: "Session") {
                                Button {
                                    showLogoutConfirmation = true
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.vendaEmber)
                                            .frame(width: 32, height: 32)
                                            .background(Color.vendaEmber.opacity(0.12))
                                            .cornerRadius(8)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Sign Out")
                                                .font(.system(size: 14, weight: .medium, design: .default))
                                                .foregroundColor(.vendaInk)
                                            Text("Clear the device session and require a fresh sign-in")
                                                .font(.system(size: 11, weight: .regular, design: .default))
                                                .foregroundColor(.vendaInkMid)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 8) {
                                Image("VendaLogo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .cornerRadius(8)
                                Text("Venda")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInk)
                                Text(appVersionLabel)
                                    .font(.system(size: 11, weight: .regular, design: .default))
                                    .foregroundColor(.vendaInkLt)
                            }
                            .padding(.vertical, 20)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .alert("Sign out of Venda?", isPresented: $showLogoutConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Sign Out", role: .destructive) {
                appState.logout()
            }
        } message: {
            Text("You’ll need to sign in again before this device can sync or process staff actions.")
        }
    }
}

private struct OperationalStatusCard: View {
    let roleTitle: String
    let companyCode: String
    let lastSyncLabel: String
    let isOnline: Bool
    let isSyncing: Bool

    var body: some View {
        VendaCard(accentColor: isOnline ? .vendaForest : .vendaOchre) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Operational Status")
                            .font(.system(size: 14, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        Text("\(roleTitle) session on \(companyCode)")
                            .font(.system(size: 12, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }
                    Spacer()
                    Text(isSyncing ? "Syncing" : (isOnline ? "Online" : "Offline"))
                        .font(.system(size: 10, weight: .bold, design: .default))
                        .foregroundColor(isOnline ? .vendaForestDk : .vendaOchreDk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(isOnline ? Color.vendaForestLt : Color.vendaOchreLt)
                        .cornerRadius(999)
                }

                Divider()

                HStack {
                    OperationalFact(title: "Last sync", value: lastSyncLabel)
                    OperationalFact(title: "Mode", value: isOnline ? "Connected" : "Device cache")
                }
            }
        }
    }
}

private struct OperationalFact: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .default))
                .foregroundColor(.vendaInkLt)
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(.vendaInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .buttonStyle(.plain)
    }
}

private struct BusinessProfileScreen: View {
    let currentUser: CurrentUser?
    @State private var copied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VendaCard(backgroundColor: .vendaForestDk) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(currentUser?.businessName ?? "Business")
                            .font(.system(size: 22, weight: .bold, design: .default))
                            .foregroundColor(.white)
                        Text(currentUser?.businessType ?? "Retail")
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.8))
                        Text("Company code: \(currentUser?.companyCode ?? "VND-0000")")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.vendaOchre)
                    }
                }

                DetailCard(title: "Business profile") {
                    DetailRow(label: "Operator", value: currentUser?.name ?? "Unknown")
                    DetailRow(label: "Phone", value: currentUser?.phone ?? "Not available")
                    DetailRow(label: "Currency", value: currentUser?.currency ?? "ZMW")
                    DetailRow(label: "Role", value: currentUser?.role.rawValue.capitalized ?? "Staff")
                }

                DetailCard(title: "Workspace access") {
                    DetailRow(label: "Company code", value: currentUser?.companyCode ?? "VND-0000")
                    Button("Copy company code") {
                        UIPasteboard.general.string = currentUser?.companyCode ?? "VND-0000"
                        copied = true
                    }
                    .font(.system(size: 13, weight: .semibold, design: .default))
                    .foregroundColor(.vendaForest)
                }

                DetailCard(title: "Operational notes") {
                    Text("This build stores a working offline snapshot on the device and syncs again when connectivity returns. Use the admin console for staff onboarding and role changes.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(Color.vendaSand)
        .navigationTitle("Account Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Company code copied", isPresented: $copied) {
            Button("OK", role: .cancel) {}
        }
    }
}

private struct NotificationPreferencesScreen: View {
    @AppStorage("notifications.lowStock") private var lowStockAlerts = true
    @AppStorage("notifications.creditDue") private var creditAlerts = true
    @AppStorage("notifications.dailySummary") private var dailySummary = false
    @AppStorage("notifications.syncHealth") private var syncHealth = true

    var body: some View {
        Form {
            Section("Operational alerts") {
                Toggle("Low stock warnings", isOn: $lowStockAlerts)
                Toggle("Sync health notices", isOn: $syncHealth)
            }

            Section("Finance reminders") {
                Toggle("Credit due reminders", isOn: $creditAlerts)
                Toggle("Daily summary prompt", isOn: $dailySummary)
            }

            Section {
                Text("These preferences control reminders on this device. They do not currently send system push notifications to other staff devices.")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundColor(.vendaInkMid)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StaffRolesScreen: View {
    @ObservedObject var appState: AppState
    @StateObject private var viewModel: AdminPanelViewModel

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: AdminPanelViewModel(appState: appState))
    }

    var body: some View {
        List {
            Section("Workspace") {
                LabeledContent("Company Code", value: appState.currentUser?.companyCode ?? "VND-0000")
                LabeledContent("Business", value: appState.currentUser?.businessName ?? "Venda")
            }

            Section("Team") {
                if viewModel.isLoading {
                    ProgressView("Loading team...")
                } else if viewModel.staff.isEmpty {
                    Text("No staff found yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.staff) { member in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                            Text("\(member.role.rawValue.capitalized) • \(member.isActive ? "Active" : "Inactive")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Staff & Roles")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadStaff()
        }
    }
}

private struct HelpSupportScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailCard(title: "Daily checks") {
                    SupportBullet(text: "Confirm the device is online before expecting live staff changes or fresh reports.")
                    SupportBullet(text: "Review the Money tab for pending mobile money and overdue credit before closing the day.")
                    SupportBullet(text: "Use Reports to compare payment mix and top products when numbers feel off.")
                }

                DetailCard(title: "If something looks wrong") {
                    SupportBullet(text: "Refresh the affected screen by leaving and returning after sync settles.")
                    SupportBullet(text: "Verify the correct company code and staff role are active on this device.")
                    SupportBullet(text: "If the app is offline, expect the UI to fall back to the device snapshot until connectivity returns.")
                }

                DetailCard(title: "Before escalating") {
                    SupportBullet(text: "Capture the sale reference, company code, and approximate time of the issue.")
                    SupportBullet(text: "Note whether the device was online or offline when the issue happened.")
                    SupportBullet(text: "Include screenshots of the affected screen and any visible error message.")
                }
            }
            .padding(16)
        }
        .background(Color.vendaSand)
        .navigationTitle("Help & Support")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct LegalSummaryScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                DetailCard(title: "Data handling") {
                    SupportBullet(text: "The app keeps a local working copy of sales, stock, money, and staff information on the device for offline-first use.")
                    SupportBullet(text: "Successful sync attempts update the shared backend when connectivity is available.")
                }

                DetailCard(title: "Privacy expectations") {
                    SupportBullet(text: "Company codes and staff PINs control access to the workspace, so treat them like operational secrets.")
                    SupportBullet(text: "Only share the device with authorized staff, especially when session sign-in remains active.")
                }

                DetailCard(title: "Build notes") {
                    Text("This screen summarizes how the current build behaves operationally. It is not a substitute for your organization’s formal privacy policy or customer terms.")
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .background(Color.vendaSand)
        .navigationTitle("Terms & Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailCard<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VendaCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundColor(.vendaInk)
                content
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.vendaInkMid)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .default))
                .foregroundColor(.vendaInk)
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct SupportBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.vendaForest)
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundColor(.vendaInkMid)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    MoreScreen()
        .environmentObject(AppState())
}

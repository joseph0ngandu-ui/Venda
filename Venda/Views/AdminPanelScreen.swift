import SwiftUI

struct AdminPanelScreen: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: AdminPanelViewModel
    @State private var showCreateSheet = false
    @State private var selectedMember: StaffProfileResponse?

    init(appState: AppState) {
        self.appState = appState
        _viewModel = StateObject(wrappedValue: AdminPanelViewModel(appState: appState))
    }

    private var canEditStaff: Bool {
        guard let role = appState.currentUser?.role else { return false }
        return role == .admin || role == .owner
    }

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(DesignSystem.Radius.md)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text("Admin Console")
                            .font(DesignSystem.Typography.h4)
                            .foregroundColor(.vendaInk)
                        Text("Live team access management")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.vendaInkMid)
                    }

                    Spacer()

                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(DesignSystem.Typography.button)
                            .foregroundColor(canEditStaff ? .vendaForest : .vendaInkLt)
                            .frame(width: 40, height: 40)
                            .background(canEditStaff ? Color.vendaForestLt : Color.vendaLine)
                            .cornerRadius(DesignSystem.Radius.md)
                    }
                    .disabled(!canEditStaff)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.lg)

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        VendaCard(backgroundColor: .vendaForestDk) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Company Code")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.white.opacity(0.8))
                                Text(appState.currentUser?.companyCode ?? "VND-ERROR")
                                    .font(DesignSystem.Typography.h1)
                                    .foregroundColor(.vendaOchre)
                                Text("Share this code with staff, then assign their PINs here.")
                                    .font(DesignSystem.Typography.captionSmall)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let message = viewModel.errorMessage {
                            VendaCard(accentColor: .vendaEmber) {
                                Text(message)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.vendaInk)
                            }
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            HStack {
                                Text("Team Directory")
                                    .font(DesignSystem.Typography.h3)
                                    .foregroundColor(.vendaInk)
                                Spacer()
                                if viewModel.isLoading {
                                    ProgressView()
                                        .tint(.vendaForest)
                                }
                            }

                            if viewModel.staff.isEmpty, !viewModel.isLoading {
                                EmptyStateCard(
                                    icon: "person.2",
                                    title: "No team members yet",
                                    message: "Create staff accounts here so the join-business flow is ready for your whole team."
                                )
                            } else {
                                LazyVStack(spacing: DesignSystem.Spacing.md) {
                                    ForEach(viewModel.staff, id: \.id) { member in
                                        StaffRow(member: member, canEdit: canEditStaff) {
                                            selectedMember = member
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxxl)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await viewModel.loadStaff()
        }
        .sheet(isPresented: $showCreateSheet) {
            StaffEditorSheet(mode: .create) { name, role, pin, _ in
                await viewModel.createStaff(name: name, role: role, pin: pin ?? "")
            }
        }
        .sheet(item: $selectedMember) { member in
            StaffEditorSheet(mode: .edit(member)) { name, role, pin, isActive in
                await viewModel.updateStaff(
                    member: member,
                    name: name,
                    role: role,
                    pin: pin,
                    isActive: isActive
                )
            }
        }
    }
}

private struct StaffRow: View {
    let member: StaffProfileResponse
    let canEdit: Bool
    let onEdit: () -> Void

    private var roleColor: Color {
        switch member.role {
        case .admin, .owner:
            return .vendaEmber
        case .manager:
            return .vendaForest
        case .cashier:
            return .vendaOchre
        }
    }

    var body: some View {
        VendaCard {
            HStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.18))
                        .frame(width: DesignSystem.ComponentSize.avatarSmall, height: DesignSystem.ComponentSize.avatarSmall)
                    Text(String(member.name.prefix(1)))
                        .font(DesignSystem.Typography.h4)
                        .foregroundColor(roleColor)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    HStack {
                        Text(member.name)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(.vendaInk)

                        Text(member.role.rawValue.uppercased())
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(roleColor)
                            .cornerRadius(DesignSystem.Radius.sm)
                    }

                    Text(member.isActive ? "Active team access" : "Inactive")
                        .font(DesignSystem.Typography.captionSmall)
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                if canEdit {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.vendaInkLt)
                            .padding(DesignSystem.Spacing.sm)
                    }
                }
            }
        }
    }
}

private enum StaffEditorMode {
    case create
    case edit(StaffProfileResponse)
}

private struct StaffEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let mode: StaffEditorMode
    let onSubmit: (String, StaffRole, String?, Bool?) async -> Void

    @State private var name = ""
    @State private var role: StaffRole = .cashier
    @State private var pin = ""
    @State private var isActive = true
    @State private var isSubmitting = false

    init(mode: StaffEditorMode, onSubmit: @escaping (String, StaffRole, String?, Bool?) async -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit

        switch mode {
        case .create:
            _name = State(initialValue: "")
            _role = State(initialValue: .cashier)
            _pin = State(initialValue: "")
            _isActive = State(initialValue: true)
        case .edit(let member):
            _name = State(initialValue: member.name)
            _role = State(initialValue: member.role)
            _pin = State(initialValue: "")
            _isActive = State(initialValue: member.isActive)
        }
    }

    private var isCreateMode: Bool {
        if case .create = mode { return true }
        return false
    }

    private var title: String {
        isCreateMode ? "Add Staff Member" : "Update Staff Member"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    VendaTextField(
                        label: "Full name",
                        placeholder: "John Doe",
                        text: $name
                    )
                    
                    Picker("Role", selection: $role) {
                        Text("Admin").tag(StaffRole.admin)
                        Text("Manager").tag(StaffRole.manager)
                        Text("Cashier").tag(StaffRole.cashier)
                    }
                }

                Section("Access") {
                    VendaPasswordField(
                        label: isCreateMode ? "PIN" : "New PIN (optional)",
                        placeholder: "••••••••",
                        text: $pin
                    )
                    if !isCreateMode {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSubmitting ? "Saving..." : "Save") {
                        Task {
                            isSubmitting = true
                            await onSubmit(
                                name.trimmingCharacters(in: .whitespacesAndNewlines),
                                role,
                                pin.isEmpty ? nil : pin,
                                isCreateMode ? true : isActive
                            )
                            isSubmitting = false
                            dismiss()
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (isCreateMode && pin.isEmpty))
                }
            }
        }
    }
}

#Preview {
    AdminPanelScreen(appState: AppState())
}

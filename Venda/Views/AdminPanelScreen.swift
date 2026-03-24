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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.vendaInk)
                            .frame(width: 40, height: 40)
                            .background(Color.vendaWhite)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text("Admin Console")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.vendaInk)
                        Text("Live team access management")
                            .font(.system(size: 11))
                            .foregroundColor(.vendaInkMid)
                    }

                    Spacer()

                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(canEditStaff ? .vendaForest : .vendaInkLt)
                            .frame(width: 40, height: 40)
                            .background(canEditStaff ? Color.vendaForestLt : Color.vendaLine)
                            .cornerRadius(12)
                    }
                    .disabled(!canEditStaff)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        VendaCard(backgroundColor: .vendaForestDk) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Company Code")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                Text(appState.currentUser?.companyCode ?? "VND-ERROR")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.vendaOchre)
                                Text("Share this code with staff, then assign their PINs here.")
                                    .font(.system(size: 12))
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

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Team Directory")
                                    .font(.system(size: 15, weight: .semibold))
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
                                LazyVStack(spacing: 10) {
                                    ForEach(viewModel.staff, id: \.id) { member in
                                        StaffRow(member: member, canEdit: canEditStaff) {
                                            selectedMember = member
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
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
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(roleColor.opacity(0.18))
                        .frame(width: 40, height: 40)
                    Text(String(member.name.prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(roleColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.vendaInk)

                        Text(member.role.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(roleColor)
                            .cornerRadius(4)
                    }

                    Text(member.isActive ? "Active team access" : "Inactive")
                        .font(.system(size: 12))
                        .foregroundColor(.vendaInkMid)
                }

                Spacer()

                if canEdit {
                    Button(action: onEdit) {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(.vendaInkLt)
                            .padding(8)
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
                    TextField("Full name", text: $name)
                    Picker("Role", selection: $role) {
                        Text("Admin").tag(StaffRole.admin)
                        Text("Manager").tag(StaffRole.manager)
                        Text("Cashier").tag(StaffRole.cashier)
                    }
                }

                Section("Access") {
                    SecureField(isCreateMode ? "PIN" : "New PIN (optional)", text: $pin)
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

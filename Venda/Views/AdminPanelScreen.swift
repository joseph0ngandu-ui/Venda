import SwiftUI

struct AdminPanelScreen: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.presentationMode) var presentationMode
    
    // Mock Staff List
    @State private var staff: [StaffMember] = [
        StaffMember(id: UUID(), name: "Nsofwa", role: .admin, phone: "0977123456"),
        StaffMember(id: UUID(), name: "Chanda", role: .cashier, phone: "0966123456"),
        StaffMember(id: UUID(), name: "Mutale", role: .cashier, phone: "0955123456")
    ]
    
    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()
                
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
                            .font(.system(size: 18, weight: .semibold, design: .default))
                            .foregroundColor(.vendaInk)
                        Text("Business Management")
                            .font(.system(size: 11, weight: .regular, design: .default))
                            .foregroundColor(.vendaInkMid)
                    }
                    Spacer()
                    Rectangle().fill(Color.clear).frame(width: 40, height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Company Code Card
                        VendaCard(backgroundColor: .vendaForestDk) {
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Your Company Code")
                                        .font(.system(size: 13, weight: .medium, design: .default))
                                        .foregroundColor(.white.opacity(0.8))
                                    
                                    Text(appState.currentUser?.companyCode ?? "VND-ERROR")
                                        .font(.system(size: 32, weight: .bold, design: .default))
                                        .foregroundColor(.vendaOchre)
                                        
                                    Text("Share this code with your staff so they can join your business workspace.")
                                        .font(.system(size: 12, weight: .regular, design: .default))
                                        .foregroundColor(.white.opacity(0.8))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                            }
                        }
                        
                        // Active Staff List
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Team Directory")
                                    .font(.system(size: 15, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInk)
                                Spacer()
                                Button(action: {}) {
                                    Image(systemName: "person.badge.plus")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.vendaForest)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.vendaForestLt)
                                        .cornerRadius(8)
                                }
                            }
                            
                            VStack(spacing: 12) {
                                ForEach(staff) { member in
                                    StaffRow(member: member)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// Internal Mock Model
private struct StaffMember: Identifiable {
    let id: UUID
    let name: String
    let role: StaffRole
    let phone: String
}

private struct StaffRow: View {
    let member: StaffMember
    
    var body: some View {
        VendaCard {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(member.role == .admin ? Color.vendaForestLt : Color.vendaSand)
                        .frame(width: 40, height: 40)
                    Text(String(member.name.prefix(1)))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(member.role == .admin ? .vendaForest : .vendaInk)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(member.name)
                            .font(.system(size: 15, weight: .medium, design: .default))
                            .foregroundColor(.vendaInk)
                        
                        if member.role == .admin {
                            Text("ADMIN")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.vendaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.vendaEmber)
                                .cornerRadius(4)
                        } else if member.role == .manager {
                            Text("MANAGER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.vendaWhite)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.vendaForest)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(member.phone)
                        .font(.system(size: 12, weight: .regular, design: .default))
                        .foregroundColor(.vendaInkMid)
                }
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.vendaInkLt)
                        .padding(8)
                }
            }
        }
    }
}

#Preview {
    AdminPanelScreen()
        .environmentObject(AppState())
}

import SwiftUI

struct BusinessRegistrationScreen: View {
    var onNext: (String, String, String, String) -> Void
    
    @State private var businessName = ""
    @State private var ownerName = ""
    @State private var phone = ""
    @State private var selectedType = ""

    let businessTypes = [
        ("Salon / Barber", "scissors"),
        ("Mini Mart", "cart.fill"),
        ("Café & Food", "cup.and.saucer.fill"),
        ("Pharmacy", "cross.case.fill"),
        ("Fashion", "tshirt.fill"),
        ("Other", "briefcase.fill")
    ]

    var isValid: Bool {
        !businessName.isEmpty && !ownerName.isEmpty && phone.count >= 9 && !selectedType.isEmpty
    }

    var body: some View {
        ZStack {
            Color.vendaSand
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header & Progress
                VStack(spacing: 20) {
                    HStack {
                        ProgressDot(isActive: true)
                        ProgressDot(isActive: false)
                        ProgressDot(isActive: false)
                    }
                    .padding(.top, 16)

                    Text("Tell us about your business")
                        .font(.system(size: 24, weight: .semibold, design: .default))
                        .foregroundColor(.vendaInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 24) {
                        // Forms
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Business Name")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Woodlands Salon", text: $businessName)
                                    .padding(16)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Name")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. John Banda", text: $ownerName)
                                    .padding(16)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Phone Number")
                                    .font(.system(size: 12, weight: .semibold, design: .default))
                                    .foregroundColor(.vendaInkLt)
                                
                                HStack(spacing: 12) {
                                    Text("+260")
                                        .font(.system(size: 15, weight: .medium, design: .default))
                                        .foregroundColor(.vendaInkMid)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 16)
                                        .background(Color.vendaParchment)
                                        .cornerRadius(12)
                                    
                                    TextField("977 123 456", text: $phone)
                                        .keyboardType(.numberPad)
                                        .padding(16)
                                        .background(Color.vendaWhite)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.vendaLine, lineWidth: 1))
                                }
                            }
                        }

                        // Business Type Grid (Static layout to prevent scroll tracking hangs)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Business Type")
                                .font(.system(size: 12, weight: .semibold, design: .default))
                                .foregroundColor(.vendaInkLt)
                            
                            VStack(spacing: 12) {
                                // Row 1
                                HStack(spacing: 12) {
                                    BusinessTypeCard(title: "Salon / Barber", icon: "scissors", isSelected: selectedType == "Salon / Barber") { selectedType = "Salon / Barber" }
                                    BusinessTypeCard(title: "Mini Mart", icon: "cart.fill", isSelected: selectedType == "Mini Mart") { selectedType = "Mini Mart" }
                                }
                                // Row 2
                                HStack(spacing: 12) {
                                    BusinessTypeCard(title: "Café & Food", icon: "cup.and.saucer.fill", isSelected: selectedType == "Café & Food") { selectedType = "Café & Food" }
                                    BusinessTypeCard(title: "Pharmacy", icon: "cross.case.fill", isSelected: selectedType == "Pharmacy") { selectedType = "Pharmacy" }
                                }
                                // Row 3
                                HStack(spacing: 12) {
                                    BusinessTypeCard(title: "Fashion", icon: "tshirt.fill", isSelected: selectedType == "Fashion") { selectedType = "Fashion" }
                                    BusinessTypeCard(title: "Other", icon: "briefcase.fill", isSelected: selectedType == "Other") { selectedType = "Other" }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)

                VendaButton(
                    title: "Continue",
                    action: {
                        onNext(businessName, ownerName, "+260\(phone)", selectedType)
                    },
                    isEnabled: isValid
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
        .navigationBarHidden(true)
    }
}

private struct ProgressDot: View {
    let isActive: Bool
    var body: some View {
        Circle()
            .fill(isActive ? Color.vendaForest : Color.vendaLine)
            .frame(width: 8, height: 8)
    }
}

private struct BusinessTypeCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(.system(size: 13, weight: .medium, design: .default))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 88)
            .foregroundColor(isSelected ? .vendaForestDk : .vendaInkMid)
            .background(isSelected ? Color.vendaForestLt : Color.vendaParchment)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.vendaForest : Color.vendaLine, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BusinessRegistrationScreen { _, _, _, _ in }
}

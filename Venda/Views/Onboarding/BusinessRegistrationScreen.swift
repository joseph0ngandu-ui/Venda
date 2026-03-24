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
                VStack(spacing: DesignSystem.Spacing.xl) {
                    HStack {
                        ProgressDot(isActive: true)
                        ProgressDot(isActive: false)
                        ProgressDot(isActive: false)
                    }
                    .padding(.top, DesignSystem.Spacing.md)

                    Text("Tell us about your business")
                        .font(DesignSystem.Typography.h2)
                        .foregroundColor(.vendaInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.xl)

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        // Forms
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Business Name")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. Woodlands Salon", text: $businessName)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(DesignSystem.Radius.md)
                                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Your Name")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.vendaInkLt)
                                TextField("e.g. John Banda", text: $ownerName)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(Color.vendaWhite)
                                    .cornerRadius(DesignSystem.Radius.md)
                                    .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
                            }

                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Phone Number")
                                    .font(DesignSystem.Typography.label)
                                    .foregroundColor(.vendaInkLt)
                                
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    Text("+260")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(.vendaInkMid)
                                        .padding(.horizontal, DesignSystem.Spacing.lg)
                                        .padding(.vertical, DesignSystem.Spacing.lg)
                                        .background(Color.vendaParchment)
                                        .cornerRadius(DesignSystem.Radius.md)
                                    
                                    TextField("977 123 456", text: $phone)
                                        .keyboardType(.numberPad)
                                        .padding(DesignSystem.Spacing.lg)
                                        .background(Color.vendaWhite)
                                        .cornerRadius(DesignSystem.Radius.md)
                                        .overlay(RoundedRectangle(cornerRadius: DesignSystem.Radius.md).stroke(Color.vendaLine, lineWidth: 1))
                                }
                            }
                        }

                        // Business Type Grid (Static layout to prevent scroll tracking hangs)
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Business Type")
                                .font(DesignSystem.Typography.label)
                                .foregroundColor(.vendaInkLt)
                            
                            VStack(spacing: DesignSystem.Spacing.md) {
                                // Row 1
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    BusinessTypeCard(title: "Salon / Barber", icon: "scissors", isSelected: selectedType == "Salon / Barber") { selectedType = "Salon / Barber" }
                                    BusinessTypeCard(title: "Mini Mart", icon: "cart.fill", isSelected: selectedType == "Mini Mart") { selectedType = "Mini Mart" }
                                }
                                // Row 2
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    BusinessTypeCard(title: "Café & Food", icon: "cup.and.saucer.fill", isSelected: selectedType == "Café & Food") { selectedType = "Café & Food" }
                                    BusinessTypeCard(title: "Pharmacy", icon: "cross.case.fill", isSelected: selectedType == "Pharmacy") { selectedType = "Pharmacy" }
                                }
                                // Row 3
                                HStack(spacing: DesignSystem.Spacing.md) {
                                    BusinessTypeCard(title: "Fashion", icon: "tshirt.fill", isSelected: selectedType == "Fashion") { selectedType = "Fashion" }
                                    BusinessTypeCard(title: "Other", icon: "briefcase.fill", isSelected: selectedType == "Other") { selectedType = "Other" }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xxxl)
                }
                .scrollDismissesKeyboard(.interactively)

                VendaButton(
                    title: "Continue",
                    action: {
                        onNext(businessName, ownerName, "+260\(phone)", selectedType)
                    },
                    isEnabled: isValid
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.md)
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
            .frame(width: DesignSystem.ComponentSize.progressDotSize, height: DesignSystem.ComponentSize.progressDotSize)
    }
}

private struct BusinessTypeCard: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                Text(title)
                    .font(DesignSystem.Typography.bodySemibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.ComponentSize.businessTypeCardHeight)
            .foregroundColor(isSelected ? .vendaForestDk : .vendaInkMid)
            .background(isSelected ? Color.vendaForestLt : Color.vendaParchment)
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(isSelected ? Color.vendaForest : Color.vendaLine, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    BusinessRegistrationScreen { _, _, _, _ in }
}

import SwiftUI

struct StaffPINPad: View {
    @State private var pinInput: String = ""
    var onComplete: (String) -> Void = { _ in }
    var maxDigits: Int = 4

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 16) {
                Spacer()
                ForEach(0..<maxDigits, id: \.self) { index in
                    Circle()
                        .stroke(
                            Color.vendaLine,
                            lineWidth: 2
                        )
                        .background(
                            Circle()
                                .fill(index < pinInput.count ? Color.vendaForest : Color.clear)
                        )
                        .frame(width: 24, height: 24)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)

            VStack(spacing: 12) {
                ForEach(1...3, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { col in
                            let num = (row - 1) * 3 + col
                            PINButton(number: String(num)) {
                                appendDigit(String(num))
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    // Empty placeholder to align columns perfectly
                    Color.clear
                        .frame(maxWidth: .infinity)
                        
                    PINButton(number: "0") {
                        appendDigit("0")
                    }
                    
                    Button(action: {
                        if !pinInput.isEmpty {
                            pinInput.removeLast()
                        }
                    }) {
                        Image(systemName: "delete.left.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.vendaEmber)
                            .frame(height: 64)
                            .frame(maxWidth: .infinity)
                            .background(Color.vendaParchment)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func appendDigit(_ digit: String) {
        guard pinInput.count < maxDigits else { return }
        pinInput.append(digit)
        if pinInput.count == maxDigits {
            onComplete(pinInput)
        }
    }
}

private struct PINButton: View {
    let number: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(number)
                .font(.system(size: 24, weight: .semibold, design: .default))
                .foregroundColor(.vendaInk)
                .frame(height: 64)
                .frame(maxWidth: .infinity)
                .background(Color.vendaParchment)
                .cornerRadius(12)
                .contentShape(Rectangle())
        }
    }
}

#Preview {
    StaffPINPad(onComplete: { pin in
        print("PIN entered: \(pin)")
    })
}

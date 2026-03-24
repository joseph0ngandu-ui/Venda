import SwiftUI

struct SaleReferenceView: View {
    let reference: String
    var onCopyTapped: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(reference)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.vendaInkMid)

            if let onCopyTapped = onCopyTapped {
                Button(action: onCopyTapped) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.vendaForest)
                }
            }
        }
    }
}

#Preview {
    SaleReferenceView(reference: "VND-2851") {
        print("Copied")
    }
}

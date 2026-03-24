import SwiftUI

// MARK: - Splash Screen

struct SplashScreen: View {
    var onFinished: () -> Void

    @State private var drawProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var strokeOpacity: Double = 1
    @State private var shimmerOffset: CGFloat = -200
    @State private var textOpacity: Double = 0
    @State private var containerOpacity: Double = 1
    @State private var containerScale: CGFloat = 1

    var body: some View {
        ZStack {
            // Background — full screen green
            Color(red: 0.102, green: 0.361, blue: 0.227)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                // Rounded square icon container (matches the app icon shape)
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color(red: 0.102, green: 0.361, blue: 0.227))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .frame(width: 130, height: 130)

                    ZStack {
                        // 1. The stroke that draws on progressively
                        VendaVShape()
                            .trim(from: 0, to: drawProgress)
                            .stroke(
                                Color.white,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: 74, height: 74)
                            .opacity(strokeOpacity)

                        // 2. The filled letter that replaces the stroke
                        VendaVShape()
                            .fill(Color.white)
                            .frame(width: 74, height: 74)
                            .opacity(fillOpacity)

                        // 3. Shimmer overlay on the filled letter
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.5), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 50)
                            .offset(x: shimmerOffset)
                            .mask(
                                VendaVShape()
                                    .fill(Color.white)
                                    .frame(width: 74, height: 74)
                            )
                            .opacity(fillOpacity)
                    }
                }
                .scaleEffect(containerScale)
                .opacity(containerOpacity)

                // Wordmark + tagline
                VStack(spacing: 5) {
                    Text("VENDA")
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .tracking(5)
                        .foregroundColor(.white)
                    Text("merchant operations")
                        .font(.system(size: 10, weight: .medium, design: .default))
                        .tracking(2)
                        .foregroundColor(.white.opacity(0.45))
                }
                .opacity(textOpacity)

                Spacer()
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
        // Phase 1: Draw the V outline (0s – 0.9s)
        withAnimation(.easeInOut(duration: 0.9)) {
            drawProgress = 1.0
        }

        // Phase 2: Cross-fade stroke -> fill (0.9s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeIn(duration: 0.25)) {
                fillOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.2)) {
                strokeOpacity = 0
            }
        }

        // Phase 3: Shimmer sweep (1.15s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeInOut(duration: 0.55)) {
                shimmerOffset = 200
            }
        }

        // Phase 4: Fade in tagline (1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeIn(duration: 0.35)) {
                textOpacity = 1
            }
        }

        // Phase 5: Exit — scale up slightly and fade (2.0s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.45)) {
                containerScale = 1.08
                containerOpacity = 0
                textOpacity = 0
            }
        }

        // Phase 6: Hand off (2.55s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.55) {
            onFinished()
        }
    }
}

// MARK: - The "V" Shape
// Precisely traces the perimeter of the Venda logo based on pixel measurements.
// This allows `.trim(from:to:)` to draw the exact serif outline before filling.

struct VendaVShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Starting at top-left of the left serif, going clockwise around the perimeter.

        // 1. Top-left outer
        p.move(to: CGPoint(x: w * 0.000, y: h * 0.000))
        // 2. Top-left inner
        p.addLine(to: CGPoint(x: w * 0.502, y: h * 0.000))

        // 3. Inner left curve/drop
        p.addLine(to: CGPoint(x: w * 0.411, y: h * 0.100))
        p.addLine(to: CGPoint(x: w * 0.456, y: h * 0.300))
        p.addLine(to: CGPoint(x: w * 0.532, y: h * 0.500))
        p.addLine(to: CGPoint(x: w * 0.568, y: h * 0.600))
        
        // 4. Inner apex
        p.addLine(to: CGPoint(x: w * 0.604, y: h * 0.650))

        // 5. Inner right curve/rise
        p.addLine(to: CGPoint(x: w * 0.640, y: h * 0.600))
        p.addLine(to: CGPoint(x: w * 0.676, y: h * 0.500))
        p.addLine(to: CGPoint(x: w * 0.745, y: h * 0.300))
        p.addLine(to: CGPoint(x: w * 0.751, y: h * 0.100))

        // 6. Top-right inner
        p.addLine(to: CGPoint(x: w * 0.667, y: h * 0.000))
        // 7. Top-right outer
        p.addLine(to: CGPoint(x: w * 1.000, y: h * 0.000))

        // 8. Outer right curve/drop
        p.addLine(to: CGPoint(x: w * 0.937, y: h * 0.100))
        p.addLine(to: CGPoint(x: w * 0.832, y: h * 0.300))
        p.addLine(to: CGPoint(x: w * 0.754, y: h * 0.500))
        p.addLine(to: CGPoint(x: w * 0.718, y: h * 0.600))
        p.addLine(to: CGPoint(x: w * 0.643, y: h * 0.800))
        
        // 9. Bottom right toe
        p.addLine(to: CGPoint(x: w * 0.580, y: h * 1.000))
        // 10. Bottom left toe
        p.addLine(to: CGPoint(x: w * 0.429, y: h * 1.000))

        // 11. Outer left curve/rise
        p.addLine(to: CGPoint(x: w * 0.357, y: h * 0.800))
        p.addLine(to: CGPoint(x: w * 0.285, y: h * 0.600))
        p.addLine(to: CGPoint(x: w * 0.249, y: h * 0.500))
        p.addLine(to: CGPoint(x: w * 0.171, y: h * 0.300))
        p.addLine(to: CGPoint(x: w * 0.069, y: h * 0.100))

        p.closeSubpath()
        return p
    }
}

#Preview {
    SplashScreen(onFinished: {})
}

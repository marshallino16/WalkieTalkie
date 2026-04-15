import SwiftUI

struct AudioWaveOverlay: View {
    let audioLevel: Float // 0...1
    let isActive: Bool

    @State private var phase: CGFloat = 0

    var body: some View {
        if isActive {
            Canvas { context, size in
                let centerY = size.height * 0.5
                let amplitude = CGFloat(audioLevel) * size.height * 0.35
                let wavelength = size.width / 3

                // Draw multiple wave lines
                for i in 0..<3 {
                    let opacity = 1.0 - Double(i) * 0.15
                    let lineAmplitude = amplitude * (1.0 - CGFloat(i) * 0.25)
                    let phaseOffset = phase + CGFloat(i) * 0.8

                    var path = Path()
                    for x in stride(from: 0, through: size.width, by: 2) {
                        let normalizedX = x / wavelength
                        let y = centerY + sin(normalizedX * .pi * 2 + phaseOffset) * lineAmplitude
                        if x == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }

                    context.stroke(
                        path,
                        with: .color(WTTheme.black.opacity(opacity)),
                        style: StrokeStyle(lineWidth: 4 - CGFloat(i) * 0.5, lineCap: .round)
                    )
                }
            }
            .allowsHitTesting(false)
            .onChange(of: audioLevel) {
                // Animate phase based on audio level
                withAnimation(.linear(duration: 0.05)) {
                    phase += CGFloat(max(0.1, audioLevel)) * 0.3
                }
            }
        }
    }
}

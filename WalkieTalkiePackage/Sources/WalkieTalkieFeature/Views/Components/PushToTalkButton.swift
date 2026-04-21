import SwiftUI

struct PushToTalkButton: View {
    let isRecording: Bool
    let progress: Double
    var accentColor: Color = WTTheme.yellow
    let onStart: () -> Void
    let onStop: () -> Void

    @State private var isPressing = false
    @State private var pulseScale: CGFloat = 1.0

    private var accentColorDark: Color {
        accentColor.opacity(0.8)
    }

    var body: some View {
        ZStack {
            // Pulse ring when recording
            if isRecording {
                Circle()
                    .fill(accentColor.opacity(0.15))
                    .frame(width: WTTheme.pttButtonSize + 40, height: WTTheme.pttButtonSize + 40)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                            pulseScale = 1.15
                        }
                    }
                    .onDisappear {
                        pulseScale = 1.0
                    }
            }

            // Progress ring
            Circle()
                .stroke(WTTheme.mediumGray, lineWidth: 4)
                .frame(width: WTTheme.pttButtonSize + 12, height: WTTheme.pttButtonSize + 12)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: WTTheme.pttButtonSize + 12, height: WTTheme.pttButtonSize + 12)
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.05), value: progress)

            // Main button
            Circle()
                .fill(
                    isRecording
                        ? LinearGradient(colors: [accentColor, accentColorDark], startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [WTTheme.darkGray, WTTheme.black], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: WTTheme.pttButtonSize, height: WTTheme.pttButtonSize)
                .overlay(
                    Circle()
                        .strokeBorder(
                            isRecording ? accentColorDark : WTTheme.mediumGray,
                            lineWidth: 3
                        )
                )
                .overlay(
                    VStack(spacing: 4) {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(isRecording ? .black : accentColor)
                            .symbolEffect(.variableColor.iterative, isActive: isRecording)

                        if !isRecording {
                            Text("PUSH")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(accentColor.opacity(0.7))
                                .tracking(2)
                        }
                    }
                )
                .scaleEffect(isPressing ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressing)
        }
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressing {
                        isPressing = true
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        onStart()
                    }
                }
                .onEnded { _ in
                    isPressing = false
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onStop()
                }
        )
    }
}

import SwiftUI

struct VoiceMessageRow: View {
    let message: VoiceMessage
    let isPlaying: Bool
    let onTap: () -> Void

    @State private var timeRemaining: TimeInterval

    init(message: VoiceMessage, isPlaying: Bool, onTap: @escaping () -> Void) {
        self.message = message
        self.isPlaying = isPlaying
        self.onTap = onTap
        self._timeRemaining = State(initialValue: message.timeRemaining)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Play indicator
                ZStack {
                    Circle()
                        .fill(WTTheme.yellow)
                        .frame(width: 44, height: 44)

                    if isPlaying {
                        Image(systemName: "waveform")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.black)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                            .offset(x: 2)
                    }
                }

                // Message info
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.senderName)
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        // Duration
                        Label {
                            Text(formatDuration(message.duration))
                                .font(WTTheme.monoSmallFont)
                        } icon: {
                            Image(systemName: "waveform")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(WTTheme.lightGray)

                        // Expiration countdown
                        Label {
                            Text(formatCountdown(timeRemaining))
                                .font(WTTheme.monoSmallFont)
                        } icon: {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(timeRemaining < 60 ? WTTheme.red : WTTheme.lightGray)
                    }
                }

                Spacer()

                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(WTTheme.mediumGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(WTTheme.darkGray)
            .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
        }
        .buttonStyle(.plain)
        .task {
            // Update countdown every second
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                timeRemaining = message.timeRemaining
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        return "\(seconds)s"
    }

    private func formatCountdown(_ remaining: TimeInterval) -> String {
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

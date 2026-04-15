import SwiftUI

struct RadioFrequencyDisplay: View {
    let frequencyNumber: String
    let channelName: String

    var body: some View {
        VStack(spacing: 8) {
            Text("FREQUENCY CHANNEL")
                .font(WTTheme.captionFont)
                .foregroundStyle(WTTheme.black.opacity(0.6))
                .tracking(2)

            // Digital frequency readout
            Text(frequencyNumber)
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundStyle(WTTheme.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(WTTheme.black.opacity(0.1), lineWidth: 1)
                )

            Text(channelName.uppercased())
                .font(WTTheme.headlineFont)
                .foregroundStyle(WTTheme.black)
                .tracking(1)
        }
    }
}

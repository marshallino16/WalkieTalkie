import SwiftUI

struct FrequencyRow: View {
    let frequency: Frequency
    let memberCount: Int
    let unreadCount: Int

    var body: some View {
        HStack(spacing: 14) {
            // Radio icon with signal
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(WTTheme.yellow)
                    .frame(width: 48, height: 48)

                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)

                // Unread badge
                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(WTTheme.red)
                        .clipShape(.capsule)
                        .overlay(
                            Capsule().strokeBorder(WTTheme.black, lineWidth: 2)
                        )
                        .offset(x: 18, y: -18)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(frequency.name)
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                }

                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 11))
                    Text("\(memberCount)")
                        .font(WTTheme.captionFont)

                    Text("·")

                    Text(frequency.displayFrequency)
                        .font(WTTheme.monoSmallFont)
                }
                .foregroundStyle(WTTheme.lightGray)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(WTTheme.mediumGray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(WTTheme.darkGray)
        .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
    }
}

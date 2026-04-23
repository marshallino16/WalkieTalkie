import SwiftUI

struct RemovalOverlayView: View {
    let reason: FrequencyDetailViewModel.RemovalReason
    let frequencyName: String
    let onDismiss: () -> Void

    @State private var appeared = false

    private var icon: String {
        switch reason {
        case .kicked: "person.fill.xmark"
        case .banned: "hand.raised.slash.fill"
        }
    }

    private var title: String {
        L10n.string(reason == .banned ? "removal.banned.title" : "removal.kicked.title")
    }

    private var message: String {
        L10n.string(reason == .banned ? "removal.banned.message" : "removal.kicked.message", frequencyName)
    }

    private var accentColor: Color {
        reason == .banned ? WTTheme.red : .orange
    }

    var body: some View {
        ZStack {
            // Blurred dark background
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()

                // Icon with pulsing ring
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(accentColor.opacity(0.2), lineWidth: 3)
                        .frame(width: 120, height: 120)
                        .scaleEffect(appeared ? 1.1 : 0.8)

                    // Inner filled circle
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: icon)
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(accentColor)
                        .symbolEffect(.pulse, isActive: appeared)
                }
                .scaleEffect(appeared ? 1 : 0.5)
                .padding(.bottom, 32)

                // Title
                Text(title)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                // Message
                Text(message)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)

                // Frequency name tag
                HStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .bold))
                    Text(frequencyName)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.white.opacity(0.08))
                .clipShape(.capsule)
                .padding(.bottom, 48)

                Spacer()

                // Dismiss button
                Button {
                    onDismiss()
                } label: {
                    Text(L10n.string("removal.dismiss"))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 30)
        }
        .transition(.opacity)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}

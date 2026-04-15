import SwiftUI

enum QuickReaction: String, CaseIterable, Identifiable {
    case roger = "ROGER"
    case copy = "COPY"
    case tenFour = "10-4"
    case over = "OVER"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .roger: return "🫡"
        case .copy: return "👍"
        case .tenFour: return "✅"
        case .over: return "✋"
        }
    }

    /// Tone frequencies for synthesized beep (in Hz)
    var tones: [Double] {
        switch self {
        case .roger: return [800, 1200]           // rising
        case .copy: return [1000, 1000]           // double tap
        case .tenFour: return [1400, 900, 1400]   // triple
        case .over: return [600]                   // single long
        }
    }
}

struct QuickReactionBar: View {
    let onReaction: (QuickReaction) -> Void
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 8) {
            ForEach(QuickReaction.allCases) { reaction in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onReaction(reaction)
                } label: {
                    VStack(spacing: 2) {
                        Text(reaction.emoji)
                            .font(.system(size: 22))
                        Text(reaction.rawValue)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .foregroundStyle(WTTheme.black)
                            .tracking(0.5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 12))
                }
                .disabled(!isEnabled)
                .opacity(isEnabled ? 1 : 0.4)
            }
        }
    }
}

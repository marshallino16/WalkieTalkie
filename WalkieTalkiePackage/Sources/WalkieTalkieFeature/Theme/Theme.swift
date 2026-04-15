import SwiftUI

public enum WTTheme {
    // MARK: - Colors
    static let yellow = Color(red: 1.0, green: 0.84, blue: 0.0)       // #FFD600
    static let yellowDark = Color(red: 0.9, green: 0.75, blue: 0.0)   // Pressed state
    static let black = Color(red: 0.06, green: 0.06, blue: 0.06)      // #0F0F0F
    static let darkGray = Color(red: 0.12, green: 0.12, blue: 0.12)   // Cards
    static let mediumGray = Color(red: 0.2, green: 0.2, blue: 0.2)    // Borders
    static let lightGray = Color(red: 0.6, green: 0.6, blue: 0.6)     // Secondary text
    static let red = Color(red: 1.0, green: 0.3, blue: 0.3)           // Expiration countdown
    static let green = Color(red: 0.3, green: 0.9, blue: 0.4)         // Online/active

    // MARK: - Typography
    static let titleFont: Font = .system(size: 32, weight: .black, design: .rounded)
    static let headlineFont: Font = .system(size: 22, weight: .bold, design: .rounded)
    static let bodyFont: Font = .system(size: 16, weight: .medium, design: .rounded)
    static let captionFont: Font = .system(size: 13, weight: .semibold, design: .rounded)
    static let monoFont: Font = .system(size: 48, weight: .bold, design: .monospaced)
    static let monoSmallFont: Font = .system(size: 14, weight: .medium, design: .monospaced)

    // MARK: - Dimensions
    static let cornerRadius: CGFloat = 16
    static let smallCornerRadius: CGFloat = 10
    static let pttButtonSize: CGFloat = 100
    static let speakerDotSize: CGFloat = 6
    static let speakerDotSpacing: CGFloat = 12
}

// MARK: - View Modifiers

struct WTCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(WTTheme.darkGray)
            .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WTTheme.cornerRadius)
                    .strokeBorder(WTTheme.mediumGray.opacity(0.5), lineWidth: 1)
            )
    }
}

struct WTYellowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WTTheme.bodyFont)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(configuration.isPressed ? WTTheme.yellowDark : WTTheme.yellow)
            .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct WTOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WTTheme.bodyFont)
            .foregroundStyle(WTTheme.yellow)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.clear)
            .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: WTTheme.cornerRadius)
                    .strokeBorder(WTTheme.yellow, lineWidth: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func wtCard() -> some View {
        modifier(WTCardModifier())
    }
}

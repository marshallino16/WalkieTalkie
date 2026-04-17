import SwiftUI

struct OnboardingView: View {
    let onComplete: (String) -> Void

    @State private var pseudo = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 4) {
                    Text("WALKIE")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(WTTheme.yellow)

                    Text("TALKIE")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(WTTheme.yellow)
                }
                .padding(.bottom, 12)

                // Antenna icon
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 40, weight: .medium))
                    .foregroundStyle(WTTheme.yellow.opacity(0.6))
                    .padding(.bottom, 40)

                // Subtitle
                Text(L10n.string("onboarding.subtitle"))
                    .font(WTTheme.bodyFont)
                    .foregroundStyle(WTTheme.lightGray)
                    .padding(.bottom, 48)

                // Pseudo input
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("onboarding.choosePseudo"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(2)

                    TextField("", text: $pseudo, prompt: Text(L10n.string("onboarding.pseudoPlaceholder")).foregroundStyle(WTTheme.mediumGray))
                        .font(WTTheme.headlineFont)
                        .foregroundStyle(.white)
                        .padding()
                        .background(WTTheme.darkGray)
                        .clipShape(.rect(cornerRadius: WTTheme.cornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WTTheme.cornerRadius)
                                .strokeBorder(
                                    isFocused ? WTTheme.yellow : WTTheme.mediumGray,
                                    lineWidth: 2
                                )
                        )
                        .focused($isFocused)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit { submit() }
                }
                .padding(.horizontal, 32)

                Spacer()

                // Continue button
                Button(action: submit) {
                    Text(L10n.string("onboarding.go"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .buttonStyle(WTYellowButtonStyle())
                .padding(.horizontal, 32)
                .disabled(pseudo.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(pseudo.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)

                Spacer()
                    .frame(height: 40)
            }
        }
        .onAppear { isFocused = true }
    }

    private func submit() {
        let trimmed = pseudo.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        onComplete(trimmed)
    }
}

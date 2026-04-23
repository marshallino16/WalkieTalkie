import SwiftUI

struct AdminPasswordView: View {
    let cloudKit: CloudKitManager
    let onAuthenticated: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var isChecking = false
    @State private var error: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(WTTheme.red)

                Text(L10n.string("admin.password.title"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(.white)

                SecureField("", text: $password, prompt: Text("••••••••").foregroundStyle(WTTheme.mediumGray))
                    .font(WTTheme.bodyFont)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(WTTheme.darkGray)
                    .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: WTTheme.smallCornerRadius)
                            .strokeBorder(error != nil ? WTTheme.red : WTTheme.mediumGray, lineWidth: 1.5)
                    )
                    .focused($isFocused)
                    .submitLabel(.go)
                    .onSubmit { Task { await authenticate() } }
                    .padding(.horizontal, 40)

                if let error {
                    Text(error)
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.red)
                }

                Button {
                    Task { await authenticate() }
                } label: {
                    if isChecking {
                        ProgressView().tint(.black)
                    } else {
                        Text(L10n.string("admin.password.button"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                    }
                }
                .buttonStyle(WTYellowButtonStyle())
                .padding(.horizontal, 40)
                .disabled(password.isEmpty || isChecking)
                .opacity(password.isEmpty ? 0.4 : 1)

                Spacer()
                Spacer()
            }
        }
        .onAppear { isFocused = true }
    }

    private func authenticate() async {
        error = nil
        isChecking = true
        defer { isChecking = false }

        guard let storedPassword = await cloudKit.fetchAdminPassword() else {
            error = L10n.string("admin.password.error.noConfig")
            return
        }

        if password == storedPassword {
            onAuthenticated()
        } else {
            error = L10n.string("admin.password.error.wrong")
            password = ""
        }
    }
}

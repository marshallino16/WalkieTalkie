import SwiftUI

struct JoinFrequencySheet: View {
    let error: String?
    let onJoin: (String, String) -> Void // (code, displayName)

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case code, name
    }

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .fill(WTTheme.mediumGray)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text("REJOINDRE")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(WTTheme.yellow)
                    .tracking(2)

                // Code field
                VStack(alignment: .leading, spacing: 8) {
                    Text("CODE DE FRÉQUENCE")
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    TextField("", text: $code, prompt: Text("XKCD-4782").foregroundStyle(WTTheme.mediumGray))
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundStyle(WTTheme.yellow)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .padding()
                        .background(WTTheme.darkGray)
                        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WTTheme.smallCornerRadius)
                                .strokeBorder(
                                    focusedField == .code ? WTTheme.yellow : WTTheme.mediumGray,
                                    lineWidth: 1.5
                                )
                        )
                        .focused($focusedField, equals: .code)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .name }
                        .onChange(of: code) {
                            // Auto-format: strip non-alphanumeric, insert dash after 4 chars
                            let clean = String(code.uppercased().filter { $0.isLetter || $0.isNumber })
                            if clean.count > 4 {
                                let prefix = String(clean.prefix(4))
                                let suffix = String(clean.dropFirst(4).prefix(4))
                                code = "\(prefix)-\(suffix)"
                            } else {
                                code = clean
                            }
                        }
                }
                .padding(.horizontal, 24)

                // Display name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("TON PSEUDO SUR CETTE FRÉQUENCE")
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    TextField("", text: $displayName, prompt: Text("Ton pseudo...").foregroundStyle(WTTheme.mediumGray))
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding()
                        .background(WTTheme.darkGray)
                        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WTTheme.smallCornerRadius)
                                .strokeBorder(
                                    focusedField == .name ? WTTheme.yellow : WTTheme.mediumGray,
                                    lineWidth: 1.5
                                )
                        )
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 24)

                Spacer()

                // Error message
                if let error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13))
                        Text(error)
                            .font(WTTheme.captionFont)
                    }
                    .foregroundStyle(WTTheme.red)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                }

                Button {
                    let trimmedCode = code.trimmingCharacters(in: .whitespaces)
                    let trimmedName = displayName.trimmingCharacters(in: .whitespaces)
                    guard !trimmedCode.isEmpty, !trimmedName.isEmpty else { return }
                    isLoading = true
                    onJoin(trimmedCode, trimmedName)
                } label: {
                    if isLoading {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("REJOINDRE LA FRÉQUENCE")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .tracking(1)
                    }
                }
                .buttonStyle(WTYellowButtonStyle())
                .padding(.horizontal, 24)
                .disabled(isLoading || code.trimmingCharacters(in: .whitespaces).isEmpty ||
                          displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity((code.trimmingCharacters(in: .whitespaces).isEmpty ||
                          displayName.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.4 : 1)

                Spacer()
                    .frame(height: 20)
            }
        }
        .onAppear {
            focusedField = .code
            // Pre-fill with saved pseudo
            if let saved = KeychainManager.getDisplayName() {
                displayName = saved
            }
        }
    }
}

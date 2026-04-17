import SwiftUI

struct CreateFrequencySheet: View {
    let onCreate: (String, String, String) -> Void // (name, code, displayName)

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var displayName = ""
    @State private var generatedCode = Frequency.generateCode()
    @State private var copied = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case name, displayName
    }

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 20) {
                // Handle
                Capsule()
                    .fill(WTTheme.mediumGray)
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                Text(L10n.string("create.title"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(WTTheme.yellow)
                    .tracking(2)

                // Name field
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("create.nameLabel"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    TextField("", text: $name, prompt: Text(L10n.string("create.namePlaceholder")).foregroundStyle(WTTheme.mediumGray))
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                        .padding()
                        .background(WTTheme.darkGray)
                        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WTTheme.smallCornerRadius)
                                .strokeBorder(focusedField == .name ? WTTheme.yellow : WTTheme.mediumGray, lineWidth: 1.5)
                        )
                        .focused($focusedField, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .displayName }
                }
                .padding(.horizontal, 24)

                // Display name field
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("create.pseudoLabel"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    TextField("", text: $displayName, prompt: Text(L10n.string("create.pseudoPlaceholder")).foregroundStyle(WTTheme.mediumGray))
                        .font(WTTheme.bodyFont)
                        .foregroundStyle(.white)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .padding()
                        .background(WTTheme.darkGray)
                        .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: WTTheme.smallCornerRadius)
                                .strokeBorder(focusedField == .displayName ? WTTheme.yellow : WTTheme.mediumGray, lineWidth: 1.5)
                        )
                        .focused($focusedField, equals: .displayName)
                        .submitLabel(.done)
                }
                .padding(.horizontal, 24)

                // Generated code display
                VStack(spacing: 8) {
                    Text(L10n.string("create.codeLabel"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    HStack {
                        Text(generatedCode)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(WTTheme.yellow)

                        Button {
                            UIPasteboard.general.string = generatedCode
                            copied = true
                            Task {
                                try? await Task.sleep(for: .seconds(1.5))
                                copied = false
                            }
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(copied ? WTTheme.green : WTTheme.yellow)
                                .animation(.easeInOut(duration: 0.2), value: copied)
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    .background(WTTheme.darkGray)
                    .clipShape(.rect(cornerRadius: WTTheme.smallCornerRadius))
                }

                Spacer()

                Button {
                    let trimmedName = name.trimmingCharacters(in: .whitespaces)
                    let trimmedDisplay = displayName.trimmingCharacters(in: .whitespaces)
                    guard !trimmedName.isEmpty, !trimmedDisplay.isEmpty else { return }
                    onCreate(trimmedName, generatedCode, trimmedDisplay)
                } label: {
                    Text(L10n.string("create.button"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .buttonStyle(WTYellowButtonStyle())
                .padding(.horizontal, 24)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty ||
                          displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity((name.trimmingCharacters(in: .whitespaces).isEmpty ||
                          displayName.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.4 : 1)

                Spacer()
                    .frame(height: 20)
            }
        }
        .onAppear {
            focusedField = .name
            if let saved = KeychainManager.getDisplayName() {
                displayName = saved
            }
        }
    }
}

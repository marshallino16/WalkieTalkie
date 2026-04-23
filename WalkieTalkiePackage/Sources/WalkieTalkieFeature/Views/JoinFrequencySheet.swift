import SwiftUI

struct JoinFrequencySheet: View {
    let error: String?
    let onJoin: (String, String) -> Void // (code, displayName)
    let onClearError: () -> Void
    let cloudKit: CloudKitManager
    let joinedCodes: Set<String>
    let onJoinPublic: (Frequency, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var displayName = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?
    @State private var selectedTab: JoinTab = .code

    private enum Field {
        case code, name
    }

    private enum JoinTab {
        case code, explorer
    }

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 24) {
                // Handle
                Capsule()
                    .fill(WTTheme.mediumGray)
                    .frame(width: 36, height: 4)
                    .padding(.top, 8)

                Text(L10n.string("join.title"))
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(WTTheme.yellow)
                    .tracking(2)

                // Tab selector
                HStack(spacing: 0) {
                    tabButton(.code, label: L10n.string("join.tabCode"))
                    tabButton(.explorer, label: L10n.string("join.tabExplorer"))
                }
                .background(WTTheme.darkGray)
                .clipShape(.rect(cornerRadius: 8))
                .padding(.horizontal, 24)

                switch selectedTab {
                case .code:
                    codeTabContent
                case .explorer:
                    ExplorerTabView(
                        cloudKit: cloudKit,
                        joinedCodes: joinedCodes,
                        onJoin: { frequency in
                            let name = displayName.trimmingCharacters(in: .whitespaces)
                            let finalName = name.isEmpty ? (KeychainManager.getDisplayName() ?? "") : name
                            guard !finalName.isEmpty else { return }
                            onJoinPublic(frequency, finalName)
                        }
                    )
                }
            }
        }
        .onAppear {
            focusedField = .code
            if let saved = KeychainManager.getDisplayName() {
                displayName = saved
            }
        }
    }

    // MARK: - Code Tab Content

    private var codeTabContent: some View {
        VStack(spacing: 24) {
            // Code field
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.string("join.codeLabel"))
                    .font(WTTheme.captionFont)
                    .foregroundStyle(WTTheme.lightGray)
                    .tracking(1.5)

                TextField("", text: $code, prompt: Text(L10n.string("join.codePlaceholder")).foregroundStyle(WTTheme.mediumGray))
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
                        onClearError()
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
                Text(L10n.string("join.pseudoLabel"))
                    .font(WTTheme.captionFont)
                    .foregroundStyle(WTTheme.lightGray)
                    .tracking(1.5)

                TextField("", text: $displayName, prompt: Text(L10n.string("join.pseudoPlaceholder")).foregroundStyle(WTTheme.mediumGray))
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
                    Text(L10n.string("join.button"))
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

    // MARK: - Tab Button

    private func tabButton(_ tab: JoinTab, label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(1)
                .foregroundStyle(selectedTab == tab ? .black : WTTheme.lightGray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedTab == tab ? WTTheme.yellow : .clear)
                .clipShape(.rect(cornerRadius: 6))
        }
        .padding(3)
    }
}

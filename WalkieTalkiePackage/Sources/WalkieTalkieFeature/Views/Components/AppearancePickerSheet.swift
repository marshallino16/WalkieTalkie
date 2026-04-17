import SwiftUI

struct AppearancePickerSheet: View {
    let frequencyCode: String
    let onSave: (FrequencyAppearance) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedIcon: String
    @State private var selectedColor: String

    init(frequencyCode: String, current: FrequencyAppearance, onSave: @escaping (FrequencyAppearance) -> Void) {
        self.frequencyCode = frequencyCode
        self.onSave = onSave
        self._selectedIcon = State(initialValue: current.iconName)
        self._selectedColor = State(initialValue: current.colorHex)
    }

    var body: some View {
        ZStack {
            WTTheme.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Preview
                iconView(iconName: selectedIcon, colorHex: selectedColor)
                    .frame(width: 80, height: 80)
                    .padding(.top, 20)

                // Color picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("appearance.color"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                        ForEach(FrequencyAppearance.availableColors, id: \.hex) { color in
                            Button {
                                selectedColor = color.hex
                            } label: {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(hex: color.hex))
                                    .frame(height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .strokeBorder(.white, lineWidth: selectedColor == color.hex ? 3 : 0)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Icon picker
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.string("appearance.icon"))
                        .font(WTTheme.captionFont)
                        .foregroundStyle(WTTheme.lightGray)
                        .tracking(1.5)

                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                            ForEach(FrequencyAppearance.availableIcons, id: \.id) { icon in
                                Button {
                                    selectedIcon = icon.id
                                } label: {
                                    VStack(spacing: 4) {
                                        iconView(iconName: icon.id, colorHex: selectedColor)
                                            .frame(width: 56, height: 56)

                                        Text(icon.label)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(WTTheme.lightGray)
                                            .lineLimit(1)
                                    }
                                    .padding(6)
                                    .background(selectedIcon == icon.id ? WTTheme.yellow.opacity(0.15) : Color.clear)
                                    .clipShape(.rect(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(selectedIcon == icon.id ? WTTheme.yellow : Color.clear, lineWidth: 2)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Save button
                Button {
                    let appearance = FrequencyAppearance(iconName: selectedIcon, colorHex: selectedColor)
                    FrequencyAppearance.save(appearance, for: frequencyCode)
                    onSave(appearance)
                    dismiss()
                } label: {
                    Text(L10n.string("appearance.save"))
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .tracking(1)
                }
                .buttonStyle(WTYellowButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }

    @ViewBuilder
    private func iconView(iconName: String, colorHex: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(hex: colorHex))
            .overlay(
                Group {
                    if iconName == "default" {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.black)
                    } else {
                        Image(iconName, bundle: .main)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    }
                }
            )
    }
}

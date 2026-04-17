import SwiftUI

/// Icon and color customization for a frequency channel
struct FrequencyAppearance: Codable, Sendable {
    let iconName: String  // asset catalog name or "default" for SF Symbol
    let colorHex: String  // hex color for the background

    static let `default` = FrequencyAppearance(iconName: "default", colorHex: "FFD600")

    var color: Color {
        Color(hex: colorHex)
    }

    // MARK: - Available icons (asset catalog names)
    static let availableIcons: [(id: String, label: String)] = [
        ("default", "Radio"),
        ("surprised_shocked_pikachu", "Pikachu"),
        ("doge_dog", "Doge"),
        ("this_is_fine_dog", "This is fine"),
        ("sad_frog", "Pepe"),
        ("crying_cat", "Crying Cat"),
        ("polite_cat", "Polite Cat"),
        ("cat_being_yelled_at", "Cat Yelled At"),
        ("woman_yelling", "Woman Yelling"),
        ("baby_yoda_drinking_soup", "Baby Yoda"),
        ("kermit_not_my_business", "Kermit"),
        ("homer_simpson_bushes", "Homer"),
        ("patrick_i_have_3_dollars", "Patrick"),
        ("handsome_squidward", "Squidward"),
        ("ralph_wiggum_diving_through_window", "Ralph"),
        ("leonardo_dicaprio_laughing", "DiCaprio"),
        ("salt_bae", "Salt Bae"),
        ("roll_safe", "Roll Safe"),
        ("facepalm", "Facepalm"),
        ("hide_the_pain_harold", "Harold"),
        ("norton_smirking", "Norton"),
        ("crying_michael_jordan", "MJ Crying"),
        ("crying_kim_kardashian", "Kim K"),
        ("awkward_look_monkey_puppet", "Monkey"),
        ("is_this_a_pigeon", "Is This?"),
    ]

    // MARK: - Available colors
    static let availableColors: [(hex: String, name: String)] = [
        ("FFD600", "Yellow"),
        ("FF5733", "Red"),
        ("FF8C00", "Orange"),
        ("28CD41", "Green"),
        ("007AFF", "Blue"),
        ("AF52DE", "Purple"),
        ("FF2D55", "Pink"),
        ("5AC8FA", "Cyan"),
        ("FF9500", "Amber"),
        ("8E8E93", "Gray"),
    ]
}

// MARK: - Color from hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default:
            r = 1; g = 0.84; b = 0
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Persistence (per frequency code)

extension FrequencyAppearance {
    private static func key(for code: String) -> String { "appearance_\(code)" }

    static func load(for code: String) -> FrequencyAppearance {
        guard let data = UserDefaults.standard.data(forKey: key(for: code)),
              let appearance = try? JSONDecoder().decode(FrequencyAppearance.self, from: data)
        else { return .default }
        return appearance
    }

    static func save(_ appearance: FrequencyAppearance, for code: String) {
        if let data = try? JSONEncoder().encode(appearance) {
            UserDefaults.standard.set(data, forKey: key(for: code))
        }
    }
}

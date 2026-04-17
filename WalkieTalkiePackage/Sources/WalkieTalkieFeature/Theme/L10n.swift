import Foundation

/// Localization helper — loads strings from the main app bundle's Localizable.strings
enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    static func string(_ key: String, _ args: CVarArg...) -> String {
        let format = Bundle.main.localizedString(forKey: key, value: key, table: nil)
        return String(format: format, arguments: args)
    }
}

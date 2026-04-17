import Foundation
import Security

enum KeychainManager {
    private static let service = "com.genyus.roger.that"
    private static let userIDKey = "userID"
    private static let userIDBackupKey = "wt_userID"
    private static let displayNameUDKey = "wt_displayName"

    // MARK: - User ID (Keychain primary + UserDefaults backup)

    static func getUserID() -> String {
        // Try keychain first
        if let existing = keychainRead(key: userIDKey) {
            // Ensure backup is synced
            UserDefaults.standard.set(existing, forKey: userIDBackupKey)
            return existing
        }
        // Fallback to UserDefaults backup (survives reinstall if keychain is lost)
        if let backup = UserDefaults.standard.string(forKey: userIDBackupKey) {
            keychainSave(key: userIDKey, value: backup)
            return backup
        }
        // Generate new
        let newID = UUID().uuidString
        keychainSave(key: userIDKey, value: newID)
        UserDefaults.standard.set(newID, forKey: userIDBackupKey)
        return newID
    }

    // MARK: - Display Name (UserDefaults)

    static func getDisplayName() -> String? {
        UserDefaults.standard.string(forKey: displayNameUDKey)
    }

    static func setDisplayName(_ name: String) {
        UserDefaults.standard.set(name, forKey: displayNameUDKey)
    }

    // MARK: - Keychain

    private static func keychainSave(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var addQuery = query
        addQuery[kSecValueData as String] = data
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private static func keychainRead(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

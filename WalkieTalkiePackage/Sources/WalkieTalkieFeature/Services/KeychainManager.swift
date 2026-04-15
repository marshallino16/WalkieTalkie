import Foundation
import Security

enum KeychainManager {
    private static let service = "com.marshalino.walkietalkie"
    private static let userIDKey = "userID"
    private static let displayNameKey = "displayName"

    // MARK: - User ID

    static func getUserID() -> String {
        if let existing = read(key: userIDKey) {
            return existing
        }
        let newID = UUID().uuidString
        save(key: userIDKey, value: newID)
        return newID
    }

    // MARK: - Display Name

    static func getDisplayName() -> String? {
        read(key: displayNameKey)
    }

    static func setDisplayName(_ name: String) {
        save(key: displayNameKey, value: name)
    }

    // MARK: - Generic Keychain Operations

    private static func save(key: String, value: String) {
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

    private static func read(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

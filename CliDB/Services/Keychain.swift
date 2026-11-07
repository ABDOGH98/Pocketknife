import Foundation
import Security

/// Stores passwords in the macOS Keychain, so they're never written to the app's database.
enum Keychain {
    private static let service = (Bundle.main.bundleIdentifier ?? "CliDB") + ".passwords"

    static func password(for account: String) -> String? {
        var query = baseQuery(for: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Saves `password`, replacing any existing one. An empty password removes the item.
    @discardableResult
    static func setPassword(_ password: String, for account: String) -> Bool {
        guard !password.isEmpty else {
            deletePassword(for: account)
            return true
        }
        let data = Data(password.utf8)
        let status = SecItemUpdate(
            baseQuery(for: account) as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecItemNotFound {
            var item = baseQuery(for: account)
            item[kSecValueData as String] = data
            return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }

    static func deletePassword(for account: String) {
        SecItemDelete(baseQuery(for: account) as CFDictionary)
    }

    private static func baseQuery(for account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

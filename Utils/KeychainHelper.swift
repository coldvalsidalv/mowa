import Foundation
import Security

/// Тонкая обёртка над Security/Keychain для хранения чувствительных строк
/// (JWT-токен, refresh-токен). Сервис — bundle id, чтобы не пересекаться с другими приложениями.
/// Все методы nonisolated — Security framework thread-safe.
nonisolated enum KeychainHelper {
    private static let service: String = Bundle.main.bundleIdentifier ?? "com.verbum.app"

    static func save(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        // Сначала удаляем существующее значение — иначе SecItemAdd вернёт duplicate.
        delete(key)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // afterFirstUnlock — токен переживает рестарт устройства, но недоступен в locked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("⚠️ KeychainHelper: save failed for \(key), status=\(status)")
        }
    }

    static func load(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

nonisolated enum KeychainKeys {
    static let accessToken = "authAccessToken"
    static let refreshToken = "authRefreshToken"
    static let userEmail = "authUserEmail"
    static let userId = "authUserId"
}

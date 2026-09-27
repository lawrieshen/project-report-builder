import Foundation
import Security

protocol CloudCredentialStoring {
    func read() throws -> String?
    func save(_ token: String) throws
    func delete() throws
}

/// Persist only the refresh token, scoped to this application's Cognito client.
struct CloudCredentialStore: CloudCredentialStoring {
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "LawrenceShen.Project-Report-Builder.Cognito",
         kSecAttrAccount as String: CognitoConfiguration().clientID]
    }

    func read() throws -> String? {
        var query = query
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw CloudAuthError.keychain(status) }
        guard let data = result as? Data, let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw CloudAuthError.invalidResponse
        }
        return token
    }

    func save(_ token: String) throws {
        let attributes = [kSecValueData as String: Data(token.utf8)]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = Data(token.utf8)
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw CloudAuthError.keychain(added) }
        } else if status != errSecSuccess { throw CloudAuthError.keychain(status) }
    }

    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw CloudAuthError.keychain(status) }
    }
}

import Foundation
import Security

/// A service/account pair for an optional Stirling-PDF credential.
///
/// The endpoint URL is deliberately not part of this type. This boundary is
/// only for the secret and does not persist connection settings or document
/// content.
public struct StirlingPDFCredentialKey: Equatable, Hashable, Sendable {
    public let service: String
    public let account: String

    public init(service: String, account: String) {
        self.service = service
        self.account = account
    }
}

public enum StirlingPDFCredentialStoreError: Error, Equatable, Sendable {
    case invalidKey
    case emptyCredential
    case keychainStatus(Int32)
}

/// Secret storage used by the optional provider integration. Implementations
/// must never log or include credential values in errors.
public protocol StirlingPDFCredentialStore: Sendable {
    func credential(for key: StirlingPDFCredentialKey) async throws -> String?
    func save(_ credential: String, for key: StirlingPDFCredentialKey) async throws
    func removeCredential(for key: StirlingPDFCredentialKey) async throws
}

/// macOS Keychain storage scoped to a generic-password service and account.
/// `WhenUnlockedThisDeviceOnly` prevents an optional remote credential from
/// being synchronised to other devices or used while the device is locked.
public struct KeychainStirlingPDFCredentialStore: StirlingPDFCredentialStore, Sendable {
    public init() {}

    public func credential(for key: StirlingPDFCredentialKey) async throws -> String? {
        try validate(key: key)
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw StirlingPDFCredentialStoreError.keychainStatus(status)
        }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw StirlingPDFCredentialStoreError.keychainStatus(errSecDecode)
        }
        return value
    }

    public func save(_ credential: String, for key: StirlingPDFCredentialKey) async throws {
        try validate(key: key)
        guard !credential.isEmpty else { throw StirlingPDFCredentialStoreError.emptyCredential }
        guard let data = credential.data(using: .utf8) else {
            throw StirlingPDFCredentialStoreError.keychainStatus(errSecParam)
        }

        var query = baseQuery(for: key)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw StirlingPDFCredentialStoreError.keychainStatus(updateStatus)
        }

        query.merge(attributes) { _, new in new }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw StirlingPDFCredentialStoreError.keychainStatus(addStatus)
        }
    }

    public func removeCredential(for key: StirlingPDFCredentialKey) async throws {
        try validate(key: key)
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw StirlingPDFCredentialStoreError.keychainStatus(status)
        }
    }

    private func validate(key: StirlingPDFCredentialKey) throws {
        guard !key.service.isEmpty, !key.account.isEmpty else {
            throw StirlingPDFCredentialStoreError.invalidKey
        }
    }

    private func baseQuery(for key: StirlingPDFCredentialKey) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: key.service,
            kSecAttrAccount as String: key.account
        ]
    }
}

/// Deterministic credential store for unit tests and previews. It has the same
/// value-level contract as Keychain storage but never touches the real
/// Keychain and keeps values private to the actor.
public actor InMemoryStirlingPDFCredentialStore: StirlingPDFCredentialStore {
    private var values: [StirlingPDFCredentialKey: String] = [:]

    public init() {}

    public func credential(for key: StirlingPDFCredentialKey) async throws -> String? {
        try validate(key: key)
        return values[key]
    }

    public func save(_ credential: String, for key: StirlingPDFCredentialKey) async throws {
        try validate(key: key)
        guard !credential.isEmpty else { throw StirlingPDFCredentialStoreError.emptyCredential }
        values[key] = credential
    }

    public func removeCredential(for key: StirlingPDFCredentialKey) async throws {
        try validate(key: key)
        values.removeValue(forKey: key)
    }

    private func validate(key: StirlingPDFCredentialKey) throws {
        guard !key.service.isEmpty, !key.account.isEmpty else {
            throw StirlingPDFCredentialStoreError.invalidKey
        }
    }
}

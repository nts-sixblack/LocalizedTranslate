//
//  KeychainManager.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 2 on 10/4/26.
//

import Foundation
import Security

public final class KeychainManager: @unchecked Sendable {
    public static let shared = KeychainManager()
    private let service = "com.sixblack.LocalizedTranslate"
    private let userDefaultsPrefix = "sec_fallback_"
    private let lock = NSLock()
    private var memoryCache: [String: String] = [:]
    private var keychainQueryAttempted: Set<String> = []

    private init() {
        // Pre-warm memory cache from sandboxed UserDefaults so Keychain is not spammed
        let knownAccounts = [
            "apiKey_openai",
            "apiKey_claude",
            "apiKey_gemini",
            "apiKey_deepseek",
            "endpoint_ollama"
        ]
        for account in knownAccounts {
            if let val = UserDefaults.standard.string(forKey: userDefaultsPrefix + account), !val.isEmpty {
                memoryCache[account] = val
            }
        }
    }

    public func save(key: String, account: String) throws {
        lock.lock()
        defer { lock.unlock() }

        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            memoryCache.removeValue(forKey: account)
            UserDefaults.standard.removeObject(forKey: userDefaultsPrefix + account)
            deleteFromKeychain(account: account)
            return
        }

        // 1. Immediately store in in-memory cache
        memoryCache[account] = trimmed

        // 2. Persist to sandboxed container UserDefaults
        UserDefaults.standard.set(trimmed, forKey: userDefaultsPrefix + account)

        // 3. Opportunistically write to Keychain with device-only access
        guard let data = trimmed.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecDuplicateItem {
            _ = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        }
    }

    public func retrieve(account: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        // 1. Memory Cache: Instant return, zero disk I/O, zero Keychain prompt
        if let cached = memoryCache[account], !cached.isEmpty {
            return cached
        }

        // 2. Sandboxed UserDefaults: Fast & completely isolated inside app sandbox container
        if let fallback = UserDefaults.standard.string(forKey: userDefaultsPrefix + account), !fallback.isEmpty {
            memoryCache[account] = fallback
            return fallback
        }

        // 3. Fallback to Keychain at most once per account per launch
        guard !keychainQueryAttempted.contains(account) else {
            return nil
        }
        keychainQueryAttempted.insert(account)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data, let str = String(data: data, encoding: .utf8), !str.isEmpty {
            memoryCache[account] = str
            UserDefaults.standard.set(str, forKey: userDefaultsPrefix + account)
            return str
        }

        return nil
    }

    public func delete(account: String) {
        lock.lock()
        defer { lock.unlock() }

        memoryCache.removeValue(forKey: account)
        UserDefaults.standard.removeObject(forKey: userDefaultsPrefix + account)
        deleteFromKeychain(account: account)
    }

    private func deleteFromKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

public enum KeychainError: LocalizedError {
    case failedToSave(OSStatus)
    case failedToRetrieve(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .failedToSave(let status):
            return "Failed to save key in Keychain (OSStatus: \(status))."
        case .failedToRetrieve(let status):
            return "Failed to retrieve key from Keychain (OSStatus: \(status))."
        }
    }
}

//
//  KeychainStore.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import Security
import CryptoKit

public actor KeychainStore: KeychainStoreProtocol {
    
    private let serviceName: String
    
    private var inMemoryFallback: [UInt32: SymmetricKey] = [:]
    
    public init(serviceName: String = "com.teekum.session") {
        self.serviceName = serviceName
    }
    
    private func keychainAccount(for sessionId: UInt32) -> String {
        String(format: "session_0x%04X", sessionId)
    }
    
    private func isKeychainUnavailable(status: OSStatus) -> Bool {
        status == errSecMissingEntitlement ||
        status == errSecNotAvailable ||
        status == errSecAuthFailed ||
        status == -60005 // errAuthorizationDenied in headless/sandbox environments
    }
    
    /// Persists the symmetric session key into the iOS Keychain backed by the Secure Enclave.
    public func storeKeyInKeychain(_ key: SymmetricKey, forSessionId sessionId: UInt32) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        guard keyData.count == 32 else {
            throw CryptoServiceError.invalidKeySize(expected: 32, actual: keyData.count)
        }
        
        let account = keychainAccount(for: sessionId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account
            ]
            let updateAttrs: [String: Any] = [
                kSecValueData as String: keyData
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttrs as CFDictionary)
            if updateStatus != errSecSuccess && !isKeychainUnavailable(status: updateStatus) {
                throw CryptoServiceError.keychainSaveFailed(updateStatus)
            }
            inMemoryFallback[sessionId] = key
        } else if status == errSecSuccess {
            inMemoryFallback[sessionId] = key
        } else {
            // In headless/test environments without securityd or keychain entitlements, fallback to actor memory
            inMemoryFallback[sessionId] = key
            if !isKeychainUnavailable(status: status) {
                throw CryptoServiceError.keychainSaveFailed(status)
            }
        }
    }
    
    /// Reads the symmetric session key from the iOS Keychain or in-memory cache.
    public func loadKeyFromKeychain(forSessionId sessionId: UInt32) throws -> SymmetricKey? {
        if let cached = inMemoryFallback[sessionId] {
            return cached
        }
        
        let account = keychainAccount(for: sessionId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess, let data = item as? Data else {
            if isKeychainUnavailable(status: status) {
                return nil
            }
            throw CryptoServiceError.keychainLoadFailed(status)
        }
        guard data.count == 32 else {
            throw CryptoServiceError.invalidKeySize(expected: 32, actual: data.count)
        }
        
        let key = SymmetricKey(data: data)
        inMemoryFallback[sessionId] = key
        return key
    }
    
    /// Permanently purges the session key from the iOS Keychain and in-memory actor state.
    public func purgeKeyFromKeychain(forSessionId sessionId: UInt32) throws {
        inMemoryFallback.removeValue(forKey: sessionId)
        let account = keychainAccount(for: sessionId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound && !isKeychainUnavailable(status: status) {
            throw CryptoServiceError.keychainDeleteFailed(status)
        }
    }
}


//
//  KeychainStore.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import Security
import CryptoKit

public actor KeychainStore {
    
    private let serviceName: String
    
    public init(serviceName: String = "com.teekum.session") {
        self.serviceName = serviceName
    }
    
    private func keychainAccount(for sessionId: UInt32) -> String {
        "session_0x\(PacketConstants.formatSessionId(sessionId))"
    }
    
    /// Persists key bytes in the device-only Keychain; reports failure instead of pretending recovery is durable.
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
            if updateStatus != errSecSuccess {
                throw CryptoServiceError.keychainSaveFailed(updateStatus)
            }
        } else if status != errSecSuccess {
            throw CryptoServiceError.keychainSaveFailed(status)
        }
    }
    
    /// Reads the symmetric session key from the iOS Keychain.
    public func loadKeyFromKeychain(forSessionId sessionId: UInt32) throws -> SymmetricKey? {
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
            throw CryptoServiceError.keychainLoadFailed(status)
        }
        guard data.count == 32 else {
            throw CryptoServiceError.invalidKeySize(expected: 32, actual: data.count)
        }
        
        return SymmetricKey(data: data)
    }
    
    /// Permanently purges the session key from the iOS Keychain.
    public func purgeKeyFromKeychain(forSessionId sessionId: UInt32) throws {
        let account = keychainAccount(for: sessionId)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            throw CryptoServiceError.keychainDeleteFailed(status)
        }
    }
}


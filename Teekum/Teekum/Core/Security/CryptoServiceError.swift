//
//  CryptoServiceError.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum CryptoServiceError: Error, LocalizedError {
    case encryptionFailed(String)
    case authenticationFailed
    case keyGenerationFailed
    case keychainSaveFailed(OSStatus)
    case keychainLoadFailed(OSStatus)
    case keychainDeleteFailed(OSStatus)
    case keyNotFound
    case invalidKeySize(expected: Int, actual: Int)
    
    public var errorDescription: String? {
        switch self {
        case let .encryptionFailed(reason):
            return "Encryption failed: \(reason)"
        case .authenticationFailed:
            return "Tamper verification failed: authentication tag does not match Associated Authenticated Data."
        case .keyGenerationFailed:
            return "Failed to generate secure symmetric key."
        case let .keychainSaveFailed(status):
            return "Keychain item addition failed with OSStatus \(status)."
        case let .keychainLoadFailed(status):
            return "Keychain retrieval failed with OSStatus \(status)."
        case let .keychainDeleteFailed(status):
            return "Keychain deletion failed with OSStatus \(status)."
        case .keyNotFound:
            return "Requested symmetric key not found in iOS Keychain."
        case let .invalidKeySize(expected, actual):
            return "Invalid symmetric key size: expected \(expected) bytes, got \(actual) bytes."
        }
    }
}

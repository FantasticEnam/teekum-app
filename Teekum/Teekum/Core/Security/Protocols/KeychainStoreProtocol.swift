////
////  KeychainStoreProtocol.swift
////  Teekum
////
////  Created by Nicho on 05/11/26.
////
//
//import Foundation
//import Security
//import CryptoKit
//
//public protocol KeychainStoreProtocol : Sendable {
//    /// Persists the symmetric session key into the iOS Keychain backed by the Secure Enclave.
//    func storeKeyInKeychain(_ key: SymmetricKey, forSessionId sessionId: UInt32) throws
//    
//    /// Reads the symmetric session key from the iOS Keychain.
//    func loadKeyFromKeychain(forSessionId sessionId: UInt32) throws -> SymmetricKey?
//    
//    /// Permanently purges the session key from the iOS Keychain upon leaving or teardown.
//    func purgeKeyFromKeychain(forSessionId sessionId: UInt32) throws
//}

//
//  CryptoServiceProtocol.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CryptoKit

/// Authoritative contract for cryptographic operations and secure key storage.
/// Implemented as a Swift `actor` to safeguard key material in memory.
public protocol CryptoServiceProtocol: Actor {
    /// Active replay and deduplication protection filter.
    var replayFilter: ReplayProtectionFilter { get }
    
    /// Seals 30 bytes of private inner payload using authenticated symmetric encryption,
    /// binding the 10-byte cleartext envelope as Associated Authenticated Data (AAD).
    func seal(
        payload: Data,
        envelope: CleartextEnvelope,
        using key: SymmetricKey
    ) throws -> (ciphertext: Data, authTag: Data)
    
    /// Seals an inner payload directly to a 56-byte binary datagram ready for radio transmission.
    func sealToWireBytes(
        payload: Data,
        envelope: CleartextEnvelope,
        using key: SymmetricKey
    ) throws -> Data
    
    /// Verifies the 16-byte Poly1305 / AES-GCM tag against the 10-byte envelope AAD and decrypts the 30-byte payload.
    /// Throws `CryptoServiceError.authenticationFailed` if tampered by a third party.
    func open(
        ciphertext: Data,
        envelope: CleartextEnvelope,
        authTag: Data,
        using key: SymmetricKey
    ) throws -> Data
    
    /// Generates a cryptographically secure 256-bit symmetric key.
    func generateSymmetricKey() -> SymmetricKey
    
    /// Generates raw 32-byte key data suitable for GroupSession & QR invite creation
    func generateSymmetricKeyData() -> Data
}

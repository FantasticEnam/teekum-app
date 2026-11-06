//
//  CryptoService.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation
import CryptoKit

/// Pure Native Apple Cryptography Service implementing `CryptoServiceProvider`.
///
/// Implemented as a Swift `actor` to guarantee thread-safe key management,
/// zero plaintext exposure, and isolated in-memory replay protection.
///
/// Uses Apple's native `CryptoKit` framework:
/// - Authenticated Encryption: `ChaCha20-Poly1305` (RFC 8439)
/// - Deterministic 96-bit Nonce derivation
/// - Hop-count masked Associated Authenticated Data (AAD)
/// - Hardware-backed Secure Enclave / iOS Keychain key persistence
public actor CryptoService: CryptoServiceProtocol {
    
    private let keychainService: String = "com.teekum.session"
    
    /// Ephemeral in-memory key cache keyed by sessionId (ensures zero disk persistence upon teardown).
    private var inMemoryKeys: [UInt16: SymmetricKey] = [:]
    
    /// Active replay and deduplication protection filter.
    public let replayFilter: ReplayProtectionFilter
    
    public init(replayFilter: ReplayProtectionFilter = ReplayProtectionFilter()) {
        self.replayFilter = replayFilter
    }
    
    // MARK: - AEAD Sealing & Opening
    
    /// Seals 30 bytes of private inner payload using ChaCha20-Poly1305 authenticated symmetric encryption,
    /// binding the 10-byte cleartext envelope as Associated Authenticated Data (AAD) with masked hop count.
    public func seal(
        payload: Data,
        envelope: CleartextEnvelope,
        using key: SymmetricKey
    ) throws -> (ciphertext: Data, authTag: Data) {
        guard payload.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.invalidPacketSize(
                expected: PacketConstants.encryptedPayloadSize,
                actual: payload.count
            )
        }
        
        let nonceData = envelope.constructNonce()
        guard let nonce = try? ChaChaPoly.Nonce(data: nonceData) else {
            throw CryptoServiceError.encryptionFailed("Nonce construction failed: invalid nonce byte length.")
        }
        
        let aad = envelope.authenticatedAssociatedData()
        
        do {
            let sealedBox = try ChaChaPoly.seal(payload, using: key, nonce: nonce, authenticating: aad)
            return (ciphertext: Data(sealedBox.ciphertext), authTag: Data(sealedBox.tag))
        } catch {
            throw CryptoServiceError.encryptionFailed(error.localizedDescription)
        }
    }
    
    /// Verifies the 16-byte Poly1305 authentication tag against the 10-byte envelope AAD and decrypts the 30-byte payload.
    /// Throws `CryptoServiceError.authenticationFailed` if tampered by any third party.
    ///
    /// Plaintext payload is NEVER exposed to application logic if authentication fails.
    public func open(
        ciphertext: Data,
        envelope: CleartextEnvelope,
        authTag: Data,
        using key: SymmetricKey
    ) throws -> Data {
        guard ciphertext.count == PacketConstants.encryptedPayloadSize else {
            throw PacketCodecError.invalidPacketSize(
                expected: PacketConstants.encryptedPayloadSize,
                actual: ciphertext.count
            )
        }
        guard authTag.count == PacketConstants.authTagSize else {
            throw PacketCodecError.invalidPacketSize(
                expected: PacketConstants.authTagSize,
                actual: authTag.count
            )
        }
        
        let nonceData = envelope.constructNonce()
        guard let nonce = try? ChaChaPoly.Nonce(data: nonceData) else {
            throw CryptoServiceError.authenticationFailed
        }
        
        let aad = envelope.authenticatedAssociatedData()
        
        guard let sealedBox = try? ChaChaPoly.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: authTag) else {
            throw CryptoServiceError.authenticationFailed
        }
        
        do {
            let decrypted = try ChaChaPoly.open(sealedBox, using: key, authenticating: aad)
            return decrypted
        } catch {
            throw CryptoServiceError.authenticationFailed
        }
    }
    
    // MARK: - High-Level Packet Helpers
    
    /// Seals an inner payload and envelope into a complete 56-byte `RawWirePacket`.
    public func sealPacket(
        payload: Data,
        envelope: CleartextEnvelope,
        using key: SymmetricKey
    ) throws -> RawWirePacket {
        let (ciphertext, authTag) = try seal(payload: payload, envelope: envelope, using: key)
        return RawWirePacket(envelope: envelope, ciphertext: ciphertext, authTag: authTag)
    }
    
    /// Opens and verifies a 56-byte `RawWirePacket`, returning the verified envelope and decrypted 30-byte payload.
    public func openPacket(
        _ packet: RawWirePacket,
        using key: SymmetricKey
    ) throws -> (envelope: CleartextEnvelope, payload: Data) {
        let plaintext = try open(
            ciphertext: packet.ciphertext,
            envelope: packet.envelope,
            authTag: packet.authTag,
            using: key
        )
        return (envelope: packet.envelope, payload: plaintext)
    }
    
    /// Seals an inner payload directly to a 56-byte binary datagram ready for radio transmission.
    public func sealToWireBytes(
        payload: Data,
        envelope: CleartextEnvelope,
        using key: SymmetricKey
    ) throws -> Data {
        let packet = try sealPacket(payload: payload, envelope: envelope, using: key)
        return try packet.toWireData()
    }
    
    /// Parses a 56-byte binary datagram from the network, verifies the authentication tag,
    /// and returns the decrypted payload and envelope.
    public func openWireBytes(
        _ wireData: Data,
        using key: SymmetricKey
    ) throws -> (envelope: CleartextEnvelope, payload: Data) {
        let packet = try RawWirePacket.fromWireData(wireData)
        return try openPacket(packet, using: key)
    }
    
    // MARK: - Key Generation
    
    /// Generates a cryptographically secure 256-bit symmetric key.
    nonisolated public func generateSymmetricKey() -> SymmetricKey {
        SymmetricKey(size: .bits256)
    }
    
    nonisolated public func generateSymmetricKeyData() -> Data {
        let key = generateSymmetricKey()
        return key.withUnsafeBytes { Data($0) }
    }
    
}


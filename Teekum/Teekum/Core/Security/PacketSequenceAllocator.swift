//
//  PacketSequenceAllocator.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Foundation
import Security

/// Shared by every packet emitter. Keep counter records after leave so rejoining a key cannot restart its nonce space.
public actor PacketSequenceAllocator {
    private let serviceName: String

    public init(serviceName: String = "com.teekum.packet-sequences") {
        self.serviceName = serviceName
    }

    public func next(for session: GroupSession) throws -> UInt32 {
        var identity = session.symmetricKeyData
        identity.append(contentsOf: PacketConstants.encodeSessionId24(session.sessionId))
        identity.append(session.memberSlot)
        let account = SHA256.hash(data: identity).map { String(format: "%02x", $0) }.joined()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        var readQuery = query
        readQuery[kSecReturnData as String] = true
        readQuery[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let readStatus = SecItemCopyMatching(readQuery as CFDictionary, &item)
        let previous: UInt32
        if readStatus == errSecItemNotFound {
            previous = 0
        } else if readStatus == errSecSuccess, let data = item as? Data, data.count == 4 {
            previous = data.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        } else {
            throw PacketSequenceError.storage(readStatus)
        }
        guard previous < 0x00ff_ffff else { throw PacketSequenceError.exhausted }
        let counter = previous + 1
        var bigEndian = counter.bigEndian
        let value = Data(bytes: &bigEndian, count: 4)
        let status: OSStatus
        if readStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = value
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(insert as CFDictionary, nil)
        } else {
            status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: value] as CFDictionary)
        }
        guard status == errSecSuccess else { throw PacketSequenceError.storage(status) }
        return CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: counter)
    }
}

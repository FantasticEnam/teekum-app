//
//  WiFiAwareLinkHello.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 15/11/26.
//

import Foundation

/// TCP preface exchanged with an OS-paired peer before reading Meepo packets.
struct WiFiAwareLinkHello {
    static let byteCount = 23
    let attemptOrder: UUID
    let sessionID: UInt32
    let initials: String
    let relayEnabled: Bool

    func encode() throws -> Data {
        guard PacketConstants.isValidSessionId(sessionID), let initials = InitialsCodec.encode(initials) else {
            throw TransportError.sessionInvalid
        }
        var data = Data([1, relayEnabled ? 1 : 0])
        data.append(contentsOf: PacketConstants.encodeSessionId24(sessionID))
        data.append(contentsOf: initials)
        withUnsafeBytes(of: attemptOrder.uuid) { data.append(contentsOf: $0) }
        return data
    }

    static func decode(_ data: Data) throws -> Self {
        let bytes = Array(data)
        guard bytes.count == byteCount, bytes[0] == 1, bytes[1] <= 1,
              let initials = InitialsCodec.decode(Array(bytes[5..<7])) else {
            throw TransportError.handshakeFailed("Invalid Wi-Fi Aware link preface.")
        }
        let sid = bytes[2..<5].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard PacketConstants.isValidSessionId(sid) else {
            throw TransportError.sessionInvalid
        }
        let order = UUID(uuid: (bytes[7], bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14],
                                bytes[15], bytes[16], bytes[17], bytes[18], bytes[19], bytes[20], bytes[21], bytes[22]))
        return Self(attemptOrder: order, sessionID: sid, initials: initials, relayEnabled: bytes[1] == 1)
    }

    // Both endpoints prefer the socket dialed by the member with the lower session token.
    func prefersOutbound(to remote: Self) -> Bool {
        attemptOrder.uuidString < remote.attemptOrder.uuidString
    }

    func permitsLink(to remote: Self) -> Bool {
        sessionID == remote.sessionID || (relayEnabled && remote.relayEnabled)
    }
}

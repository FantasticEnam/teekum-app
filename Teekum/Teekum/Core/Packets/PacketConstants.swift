//
//  PacketConstants.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

nonisolated public enum PacketConstants {
    public static var wirePacketSize: Int { MeepoConfiguration.Network.wirePacketSize }
    public static var cleartextEnvelopeSize: Int { MeepoConfiguration.Network.cleartextEnvelopeSize }
    public static var encryptedPayloadSize: Int { MeepoConfiguration.Network.encryptedPayloadSize }
    public static var authTagSize: Int { MeepoConfiguration.Network.authTagSize }
    public static var nonceSize: Int { MeepoConfiguration.Network.nonceSize }
    
    public static var protocolVersion: UInt8 { MeepoConfiguration.Network.protocolVersion }
    public static var defaultHopLimit: UInt8 {
        get { MeepoConfiguration.Network.defaultHopLimit }
    }
    public static var chatHopLimit: UInt8 {
        get { MeepoConfiguration.Network.chatHopLimit }
    }
    public static var maxHopLimit: UInt8 {
        get { MeepoConfiguration.Network.maxHopLimit }
    }
    public static var meetingPointHopLimit: UInt8 {
        get { MeepoConfiguration.Network.meetingPointHopLimit }
    }
    public static var sosHopLimit: UInt8 {
        get { MeepoConfiguration.Network.sosHopLimit }
    }
    
    /// Validates whether a given data buffer size matches the strictly fixed 56-byte wire format.
    public static func isValidWirePacketSize(_ count: Int) -> Bool {
        count == wirePacketSize
    }
    
    /// 4-byte protocol domain tag used in nonce construction: 'T', 'K', 'M', '3'
    public static var protocolDomainTag: [UInt8] { MeepoConfiguration.Network.protocolDomainTag }

    /// Canonical 24-bit Session ID bitmask (`0x00FFFFFF`).
    public static var sessionIdMask: UInt32 { MeepoConfiguration.Network.sessionIdMask }

    /// Maximum valid 24-bit Session ID (`0x00FFFFFF`).
    public static var maxSessionId: UInt32 { MeepoConfiguration.Network.maxSessionId }

    /// Validates whether a Session ID falls within the non-zero 24-bit range (`0x000001...0xFFFFFF`).
    public static func isValidSessionId(_ sessionId: UInt32) -> Bool {
        sessionId >= 1 && sessionId <= maxSessionId
    }

    /// Encodes a 24-bit Session ID into 3 big-endian wire bytes.
    public static func encodeSessionId24(_ sessionId: UInt32) -> [UInt8] {
        let sid = sessionId & sessionIdMask
        return [
            UInt8((sid >> 16) & 0xFF),
            UInt8((sid >> 8) & 0xFF),
            UInt8(sid & 0xFF)
        ]
    }

    /// Formats a 24-bit Session ID canonically as 6 uppercase hexadecimal characters.
    public static func formatSessionId(_ sessionId: UInt32) -> String {
        String(format: "%06X", sessionId & sessionIdMask)
    }
}

//
//  PacketConstant.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

nonisolated public enum PacketConstants {
    public static var wirePacketSize: Int { TeeKumConfiguration.Network.wirePacketSize }
    public static var cleartextEnvelopeSize: Int { TeeKumConfiguration.Network.cleartextEnvelopeSize }
    public static var encryptedPayloadSize: Int { TeeKumConfiguration.Network.encryptedPayloadSize }
    public static var authTagSize: Int { TeeKumConfiguration.Network.authTagSize }
    public static var nonceSize: Int { TeeKumConfiguration.Network.nonceSize }
    
    public static var protocolVersion: UInt8 { TeeKumConfiguration.Network.protocolVersion }
    public static var defaultHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.defaultHopLimit }
    }
    public static var chatHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.chatHopLimit }
    }
    public static var uwbHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.uwbHopLimit }
    }
    public static var maxHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.maxHopLimit }
    }
    public static var meetingPointHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.meetingPointHopLimit }
    }
    public static var sosHopLimit: UInt8 {
        get { TeeKumConfiguration.Network.sosHopLimit }
    }
    
    /// Validates whether a given data buffer size matches the strictly fixed 56-byte wire format.
    public static func isValidWirePacketSize(_ count: Int) -> Bool {
        count == wirePacketSize
    }
    
    /// 4-byte protocol domain tag used in nonce construction: 'T', 'K', 'M', '3'
    public static var protocolDomainTag: [UInt8] { TeeKumConfiguration.Network.protocolDomainTag }
}

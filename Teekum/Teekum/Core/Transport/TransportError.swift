//
//  TransportError.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Transport-specific errors.
public enum TransportError: Error, LocalizedError, Equatable {
    case notStarted
    case listenerFailed(String)
    case browserFailed(String)
    case connectionFailed(String)
    case sendFailed(String)
    case invalidPacketSize
    case peerNotFound(String)
    case queueFull(String)
    case handshakeFailed(String)
    case relayDisabled
    case hopLimitExceeded(count: UInt8, limit: UInt8)
    case rateLimitExceeded(String)
    case loopDetected(String)
    case sessionInvalid
    case sessionMismatch
    case securityVerificationFailed
    case malformedPacket
    
    public var errorDescription: String? {
        switch self {
        case .notStarted:
            return "Peer transport service is not started."
        case let .listenerFailed(reason):
            return "NWListener failed: \(reason)"
        case let .browserFailed(reason):
            return "NWBrowser failed: \(reason)"
        case let .connectionFailed(reason):
            return "NWConnection failed: \(reason)"
        case let .sendFailed(reason):
            return "Packet transmission failed: \(reason)"
        case .invalidPacketSize:
            return "Wire packet size must be exactly \(PacketConstants.wirePacketSize) bytes."
        case let .peerNotFound(id):
            return "Target peer '\(id)' is not currently reachable."
        case let .queueFull(reason):
            return "Outbox queue capacity exceeded: \(reason)"
        case let .handshakeFailed(reason):
            return "Peer handshake negotiation failed: \(reason)"
        case .relayDisabled:
            return "Mesh relaying is disabled by user policy or battery constraints."
        case let .hopLimitExceeded(count, limit):
            return "Packet hop count (\(count)) reached or exceeded limit (\(limit))."
        case let .rateLimitExceeded(reason):
            return "Forwarding rate limit exceeded: \(reason)"
        case let .loopDetected(reason):
            return "Forwarding loop prevented: \(reason)"
        case .sessionInvalid:
            return "Active cryptographic session is invalid or missing."
        case .sessionMismatch:
            return "Packet session ID does not match the active group session."
        case .securityVerificationFailed:
            return "Cryptographic authentication failed: invalid Poly1305 MAC tag or expired replay timestamp."
        case .malformedPacket:
            return "Packet payload is malformed or corrupted."
        }
    }
}

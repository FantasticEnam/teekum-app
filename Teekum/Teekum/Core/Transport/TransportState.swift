//
//  TransportState.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Connection lifecycle and operational states of the peer-to-peer transport.
public enum TransportState: Equatable, Sendable {
    case stopped
    case starting
    case discovering
    case connected(peerCount: Int)
    case failed(TransportError)
    
    public var description: String {
        switch self {
        case .stopped:
            return "Stopped"
        case .starting:
            return "Starting Radio..."
        case .discovering:
            return "Searching for Nearby Peers..."
        case let .connected(count):
            return "Connected (\(count) active peer\(count == 1 ? "" : "s"))"
        case let .failed(error):
            return "Transport Failed: \(error.localizedDescription)"
        }
    }
}

//
//  TransportDiagnostics.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Live diagnostic snapshot of peer-to-peer radio telemetry for on-device HUD testing.
nonisolated public struct TransportDiagnostics: Sendable {
    public let localPeerId: String
    public let serviceType: String
    public let sessionName: String
    public let sessionId: UInt16
    public let state: TransportState
    public let activeDirectPeers: [PeerInfo]
    public let packetsSent: Int
    public let packetsReceived: Int
    public let obsoletePingsCoalesced: Int
    public let sendErrors: Int
    public let lastError: String?
    public let recentEvents: [DiagnosticEvent]
    
    public init(
        localPeerId: String,
        serviceType: String,
        sessionName: String,
        sessionId: UInt16,
        state: TransportState,
        activeDirectPeers: [PeerInfo],
        packetsSent: Int,
        packetsReceived: Int,
        obsoletePingsCoalesced: Int,
        sendErrors: Int,
        lastError: String?,
        recentEvents: [DiagnosticEvent]
    ) {
        self.localPeerId = localPeerId
        self.serviceType = serviceType
        self.sessionName = sessionName
        self.sessionId = sessionId
        self.state = state
        self.activeDirectPeers = activeDirectPeers
        self.packetsSent = packetsSent
        self.packetsReceived = packetsReceived
        self.obsoletePingsCoalesced = obsoletePingsCoalesced
        self.sendErrors = sendErrors
        self.lastError = lastError
        self.recentEvents = recentEvents
    }
}

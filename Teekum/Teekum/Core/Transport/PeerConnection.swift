//
//  PeerConnection.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network

final class PeerConnection: @unchecked Sendable {
    var peerId: String
    var displayName: String
    var endpoint: NWEndpoint
    var connection: NWConnection
    var isReady: Bool = false
    var isOutbound: Bool
    var isGroupMember: Bool
    var capabilities: TransportCapabilities
    let framer = StreamMessageFramer()
    var retryCount: Int = 0
    var lastSeen: Date = Date()
    
    init(
        peerId: String,
        displayName: String,
        endpoint: NWEndpoint,
        connection: NWConnection,
        isOutbound: Bool,
        isGroupMember: Bool = false,
        capabilities: TransportCapabilities = .standardMesh
    ) {
        self.peerId = peerId
        self.displayName = displayName
        self.endpoint = endpoint
        self.connection = connection
        self.isOutbound = isOutbound
        self.isGroupMember = isGroupMember
        self.capabilities = capabilities
    }
}

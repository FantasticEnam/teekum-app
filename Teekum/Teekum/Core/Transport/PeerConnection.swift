//
//  PeerConnection.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
import Network
import WiFiAware

/// Mutable link state is confined to PeerTransportService.
final class PeerConnection {
    let token: UUID
    let deviceID: WAPairedDevice.ID
    let peerId: String
    let displayName: String
    let connection: NetworkConnection<TCP>
    let isGroupMember: Bool
    let isReady: Bool
    let preferredDirection: Bool
    var lastSeen: Date = .now

    init(
        token: UUID,
        deviceID: WAPairedDevice.ID,
        remote: WiFiAwareLinkHello,
        local: WiFiAwareLinkHello,
        connection: NetworkConnection<TCP>,
        isOutbound: Bool
    ) {
        self.token = token
        self.deviceID = deviceID
        self.connection = connection
        isGroupMember = remote.sessionID == local.sessionID
        peerId = isGroupMember ? remote.initials : "aware-\(deviceID)"
        displayName = isGroupMember ? remote.initials : "Relay peer"
        isReady = local.permitsLink(to: remote)
        preferredDirection = isOutbound == local.prefersOutbound(to: remote)
    }
}

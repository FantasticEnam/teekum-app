//
//  PeerInfo.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Information regarding an active peer discovered over the radio link.
public struct PeerInfo: Identifiable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let rssi: Int8?
    public let isDirectLink: Bool
    public let isGroupMember: Bool
    public let lastSeen: Date
    
    public init(
        id: String,
        displayName: String,
        rssi: Int8? = nil,
        isDirectLink: Bool = true,
        isGroupMember: Bool = true,
        lastSeen: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.rssi = rssi
        self.isDirectLink = isDirectLink
        self.isGroupMember = isGroupMember
        self.lastSeen = lastSeen
    }
}

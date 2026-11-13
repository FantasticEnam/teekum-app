//
//  SessionActivityAttributes.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import ActivityKit
import Foundation

/// Shared by the app and widget; contains no session key or precise coordinates.
struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var directPeerCount = 0
        var unreadMessageCount = 0
        var meetingPointName: String?
        var meetingPointDistanceMeters: Int?
        var sosSenderInitials: String?
        var relayStatusText = "Relay off"
        var lastUpdated = Date.now
    }
    
    let sessionId: UInt32
    let sessionName: String
    let userInitials: String
    let userColorCode: UInt8
    
    init(
        sessionId: UInt32,
        sessionName: String,
        userInitials: String,
        userColorCode: UInt8 = 0x00
    ) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.userInitials = userInitials
        self.userColorCode = userColorCode
    }
}

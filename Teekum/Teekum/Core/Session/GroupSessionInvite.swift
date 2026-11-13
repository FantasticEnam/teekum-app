//
//  GroupSessionInvite.swift
//  Teekum
//
//  Created by Nicho on 07/11/26.
//

import Foundation

/// Decoded details from a serverless share link or QR barcode invite.
public struct GroupSessionInvite: Equatable, Sendable {
    /// 24-bit session identifier (`0x000001...0xFFFFFF`).
    public let sessionId: UInt32
    public let sessionName: String
    public let keyData: Data
    
    public init(sessionId: UInt32, sessionName: String, keyData: Data) {
        self.sessionId = sessionId
        self.sessionName = sessionName
        self.keyData = keyData
    }
}

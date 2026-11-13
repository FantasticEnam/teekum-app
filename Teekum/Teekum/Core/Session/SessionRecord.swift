//
//  SessionRecord.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Recovery metadata contains no key, location, roster or conversation history.
struct SessionRecord: Codable {
    let sessionId: UInt32
    let sessionName: String
    let localInitials: String
    let localColorCode: UInt8
    let isHost: Bool
    let createdAt: Date

    init(_ session: GroupSession) {
        sessionId = session.sessionId
        sessionName = session.sessionName
        localInitials = session.localInitials
        localColorCode = session.localColorCode
        isHost = session.isHost
        createdAt = session.createdAt
    }

    func session(key: Data) -> GroupSession? {
        guard PacketConstants.isValidSessionId(sessionId), key.count == 32, InitialsCodec.isValid(localInitials) else { return nil }
        return GroupSession(sessionId: sessionId, sessionName: sessionName, symmetricKeyData: key,
            localInitials: localInitials, localColorCode: localColorCode, isHost: isHost, createdAt: createdAt)
    }
}

//
//  GroupSessionFactory.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CryptoKit
import Foundation

enum GroupSessionFactory {
    static func create(name: String, initials: String, colorCode: UInt8) throws -> GroupSession {
        let cleanInitials = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard InitialsCodec.isValid(cleanInitials) else { throw PairingError.invalidInitials }
        let groupName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !groupName.isEmpty else { throw PairingError.invalidGroupName }
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        return GroupSession(
            sessionId: UInt32.random(in: 1...PacketConstants.maxSessionId),
            sessionName: groupName,
            symmetricKeyData: key,
            localInitials: cleanInitials,
            localColorCode: colorCode,
            isHost: true
        )
    }

    static func join(invite: GroupSessionInvite, initials: String, colorCode: UInt8) throws -> GroupSession {
        let cleanInitials = initials.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard InitialsCodec.isValid(cleanInitials) else { throw PairingError.invalidInitials }
        guard PacketConstants.isValidSessionId(invite.sessionId), invite.keyData.count == 32,
              !invite.sessionName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PairingError.invalidInvite
        }
        return GroupSession(
            sessionId: invite.sessionId,
            sessionName: invite.sessionName,
            symmetricKeyData: invite.keyData,
            localInitials: cleanInitials,
            localColorCode: colorCode,
            isHost: false
        )
    }
}

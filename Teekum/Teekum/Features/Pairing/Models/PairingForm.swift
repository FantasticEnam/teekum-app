//
//  PairingForm.swift
//  Teekum
//
//  Created by Ari Hasan on 07/11/26.
//


import Foundation

/// Draft input, not an active GroupSession or a parsed GroupInvite.
struct PairingForm: Equatable {
    var initials = ""
    var sessionName = ""
    var profileColor: PairingProfileColor = .yellow

    var trimmedSessionName: String {
        sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var hasValidInitials: Bool {
        InitialsCodec.isValid(initials)
    }

    var canGenerateQR: Bool {
        hasValidInitials && !trimmedSessionName.isEmpty
    }
}

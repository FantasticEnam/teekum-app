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
        (1...3).contains(initials.count) &&
        initials.allSatisfy { $0 >= "A" && $0 <= "Z" }
    }

    var canGenerateQR: Bool {
        hasValidInitials && !trimmedSessionName.isEmpty
    }
}

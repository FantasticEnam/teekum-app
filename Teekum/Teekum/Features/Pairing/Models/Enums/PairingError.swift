//
//  PairingError.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

enum PairingError: LocalizedError {
    case invalidInitials
    case invalidGroupName
    case invalidInvite
    case emptyClipboard

    var errorDescription: String? {
        switch self {
        case .invalidInitials: "Enter one to three letters for your initials."
        case .invalidGroupName: "Enter a group name."
        case .invalidInvite: "This is not a valid TeeKum group invitation."
        case .emptyClipboard: "Copy a group invitation link first."
        }
    }
}

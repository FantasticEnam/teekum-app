//
//  PacketSequenceError.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

public enum PacketSequenceError: Error, LocalizedError {
    case exhausted
    case storage(Int32)

    public var errorDescription: String? {
        switch self {
        case .exhausted: "This session has reached its packet limit. Create a new group before sending again."
        case .storage: "Unable to reserve a safe packet number. Please try again after unlocking your phone."
        }
    }
}

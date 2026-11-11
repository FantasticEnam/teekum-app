//
//  MeetingAction.swift
//  Teekum
//
//  Created by Nicho on 05/11/26.
//

import Foundation

public enum MeetingAction: UInt8, CaseIterable, Codable, Sendable {
    case propose = 0x01
    case accept  = 0x02
    case decline = 0x03
    case cancel  = 0x04
}

//
//  MeetingAttendance.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free attendance choices for the active group meeting point.
public enum MeetingAttendance: UInt8, CaseIterable, Codable, Sendable {
    case pending  = 0x00
    case accepted = 0x01
    case declined = 0x02
    case arrived  = 0x09

    public var title: String {
        switch self {
        case .pending:  return "Pending"
        case .accepted: return "I'll be there"
        case .declined: return "Can't make it"
        case .arrived:  return "Arrived"
        }
    }

    public var systemImage: String {
        switch self {
        case .pending:  return "clock.fill"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .arrived:  return "mappin.and.ellipse"
        }
    }
}

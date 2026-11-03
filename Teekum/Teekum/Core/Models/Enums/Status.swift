//
//  Status.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 02/11/26.
//

import Foundation

/// Payload-free festival activity status cases with agreed 1-byte wire code mapping.
public enum Status: UInt8, CaseIterable, Codable, Sendable {
    case available      = 0x00
    case sos            = 0x01
    case omw            = 0x02
    case lost           = 0x03
    case exploring      = 0x04
    case wait           = 0x05
    case comeToMe       = 0x06
    case goingTo        = 0x07
    case cancelMeeting  = 0x08
    case atMeetingPoint = 0x09
    case gettingDrinks  = 0x0A
    case restroom       = 0x0B
    case foodMerch      = 0x0C
    case medical        = 0x0D

    public var title: String {
        switch self {
        case .available:      return "Available"
        case .sos:            return "Emergency SOS"
        case .omw:            return "On My Way"
        case .lost:           return "I'm Lost"
        case .exploring:      return "Exploring"
        case .wait:           return "Wait for Me"
        case .comeToMe:       return "Come to Me"
        case .goingTo:        return "Going to..."
        case .cancelMeeting:  return "Meeting Cancelled"
        case .atMeetingPoint: return "At Meeting Point"
        case .gettingDrinks:  return "Getting Drinks"
        case .restroom:       return "In Restroom Line"
        case .foodMerch:      return "Food & Merch"
        case .medical:        return "Medical / First Aid"
        }
    }

    public var systemImage: String {
        switch self {
        case .available:      return "checkmark.circle.fill"
        case .sos:            return "exclamationmark.triangle.fill"
        case .omw:            return "figure.walk"
        case .lost:           return "questionmark.circle.fill"
        case .exploring:      return "safari.fill"
        case .wait:           return "hand.raised.fill"
        case .comeToMe:       return "arrow.triangle.pull"
        case .goingTo:        return "arrow.triangle.turn.up.right.diamond.fill"
        case .cancelMeeting:  return "xmark.circle.fill"
        case .atMeetingPoint: return "mappin.circle.fill"
        case .gettingDrinks:  return "wineglass.fill"
        case .restroom:       return "figure.dress.line.vertical.figure"
        case .foodMerch:      return "fork.knife"
        case .medical:        return "cross.case.fill"
        }
    }

    public var emoji: String {
        switch self {
        case .available:      return "🟢"
        case .sos:            return "🚨"
        case .omw:            return "🏃"
        case .lost:           return "❓"
        case .exploring:      return "🧭"
        case .wait:           return "✋"
        case .comeToMe:       return "👉"
        case .goingTo:        return "🎯"
        case .cancelMeeting:  return "❌"
        case .atMeetingPoint: return "📍"
        case .gettingDrinks:  return "🍻"
        case .restroom:       return "🚻"
        case .foodMerch:      return "🍔"
        case .medical:        return "🩹"
        }
    }

    /// Standard statuses selectable from the horizontal StatusPickerView on the map.
    public static var selectablePickerCases: [Status] {
        [
            .available, .omw, .gettingDrinks, .restroom,
            .foodMerch, .exploring, .wait, .comeToMe,
            .atMeetingPoint, .lost, .medical
        ]
    }

    public var isEmergency: Bool {
        self == .sos || self == .medical
    }
}

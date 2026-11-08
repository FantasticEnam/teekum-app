//
//  SOSType.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 03/11/26.
//

import Foundation

/// Payload-free emergency category codes carried in SOS alerts.
public enum SOSType: UInt8, CaseIterable, Codable, Sendable {
    case general   = 0x00
    case medical   = 0x01
    case separated = 0x02
    case security  = 0x03
    case inactivity = 0x04

    public var title: String {
        switch self {
        case .general:   return "General Emergency"
        case .medical:   return "Medical Assistance"
        case .separated: return "Lost / Separated"
        case .security:  return "Security Concern"
        case .inactivity: return "Inactivity / Man Down"
        }
    }
}

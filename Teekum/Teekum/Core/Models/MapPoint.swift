// xcode: set sdk=iOS

//
//  MapPoint.swift
//  
//
//  Created by Adiat Rahman on 05/11/26.
//
import Foundation
import CoreLocation

struct MapPoint: Identifiable, Sendable {
    let id: UInt32
    var coordinate: CLLocationCoordinate2D
    var createdAt: Date
    var proposerId: String
    var title: String
//    public var attendance: [String: AttendanceStatus]
    
    public init(
        id: UInt32 = UInt32.random(in: 1...UInt32.max),
        coordinate: CLLocationCoordinate2D,
        createdAt: Date = Date(),
        proposerId: String,
        title: String
//        attendance: [String: AttendanceStatus] = [:]
    ) {
        self.id = id
        self.coordinate = coordinate
        self.createdAt = createdAt
        self.proposerId = proposerId // InitialsCodec.sanitize(proposerId)
        self.title = title
//        self.attendance = attendance
    }
}

nonisolated public enum AttendanceStatus: UInt8, CaseIterable, Codable, Sendable {
    case attending = 0x01
    case cantMakeIt = 0x02
    
    public var title: String {
        switch self {
        case .attending: return "I'll be there"
        case .cantMakeIt: return "Can't make it"
        }
    }
}

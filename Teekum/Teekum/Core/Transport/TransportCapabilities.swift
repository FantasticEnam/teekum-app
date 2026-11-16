//
//  TransportCapabilities.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Supported physical and radio transport capabilities advertised or discovered per neighbor.
public struct TransportCapabilities: OptionSet, Sendable, Equatable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    
    public static let relayOpaque = TransportCapabilities(rawValue: 1 << 2)
    public static let urgentSOS   = TransportCapabilities(rawValue: 1 << 3)
    
    public static let wifiAwareDirect = TransportCapabilities(rawValue: 1 << 4)

    public static let standardMesh: TransportCapabilities = [.wifiAwareDirect, .relayOpaque, .urgentSOS]
}

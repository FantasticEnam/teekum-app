//
//  SystemMeshClock.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Standard system clock returning the current hardware date.
public struct SystemMeshClock: MeshClock {
    nonisolated public init() {}
    nonisolated public func now() -> Date { Date() }
}

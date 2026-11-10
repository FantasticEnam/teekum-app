//
//  MeshClockProtocol.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

/// Testable clock protocol allowing deterministic advancement of time in unit and integration tests.
public protocol MeshClock: Sendable {
    nonisolated func now() -> Date
}

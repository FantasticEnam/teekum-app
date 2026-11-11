//
//  TestMeshClock.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation
@testable import Teekum

/// Injected mock clock supporting instant, deterministic time advancement.
public final class TestMeshClock: MeshClock, @unchecked Sendable {
    private var currentDate: Date
    private let lock = NSLock()
    
    public init(initialDate: Date = Date()) {
        self.currentDate = initialDate
    }
    
    nonisolated public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return currentDate
    }
    
    nonisolated public func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        currentDate = currentDate.addingTimeInterval(seconds)
    }
}

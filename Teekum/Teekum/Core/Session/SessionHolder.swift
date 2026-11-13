//
//  SessionHolder.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Synchronous session snapshots for Sendable closures used by actors.
final class SessionHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var value: GroupSession?

    var session: GroupSession? {
        get { lock.withLock { value } }
        set { lock.withLock { value = newValue } }
    }
}

//
//  OrbitMapViewModel.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class OrbitMapViewModel {
    let sessionStore: SessionStore

    var groupName: String {
        sessionStore.activeSession?.sessionName ?? "Group Name"
    }

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    func leaveGroup() {
        // shortcut: state-only teardown; stop session publishers/transport here when those services are integrated.
        sessionStore.resetSessionState()
    }
}

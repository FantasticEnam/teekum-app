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
    private let onLeaveGroup: () -> Void

    var groupName: String {
        sessionStore.activeSession?.sessionName ?? "Group Name"
    }

    var localProfileColor: MemberColor {
        guard let session = sessionStore.activeSession else { return .sandrift }
        return sessionStore.profileColor(for: session.localInitials)
    }

    init(sessionStore: SessionStore, onLeaveGroup: (() -> Void)? = nil) {
        self.sessionStore = sessionStore
        self.onLeaveGroup = onLeaveGroup ?? sessionStore.resetSessionState
    }

    func leaveGroup() {
        onLeaveGroup()
    }
}

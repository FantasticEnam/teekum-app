//
//  PairingViewModel.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PairingViewModel {
    private let sessionStore: SessionStore

    var form = PairingForm() {
        didSet {
            if form != oldValue { isShowingQR = false }
        }
    }
    var mode: PairingMode = .create
    private(set) var isShowingQR = false

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    var canPerformPrimaryAction: Bool {
        mode == .create ? form.canGenerateQR : form.hasValidInitials
    }

    func showQRPreview() {
        guard mode == .create, form.canGenerateQR else { return }
        isShowingQR = true
    }

    // shortcut: local navigation only; replace with validated invite/session activation during P2P integration.
    func activateLocalSession() {
        guard !sessionStore.hasActiveSession,
              canPerformPrimaryAction,
              mode == .join || isShowingQR else { return }

        let session = GroupSession(
            sessionId: UInt32.random(in: 1...0xFFFFFF),
            sessionName: mode == .create ? form.trimmedSessionName : "Demo Group",
            localMemberId: MemberID(rawValue: UUID().uuidString),
            localInitials: form.initials,
            isHost: mode == .create
        )
        sessionStore.resetSessionState()
        sessionStore.activeSession = session
    }
}

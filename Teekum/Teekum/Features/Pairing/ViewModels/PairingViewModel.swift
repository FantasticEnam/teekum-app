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
    private let onActivate: @MainActor (GroupSession) -> Void

    var form = PairingForm() {
        didSet {
            if form != oldValue {
                draftSession = nil
                isPublicFestivalMesh = false
            }
        }
    }
    var mode: PairingMode = .create {
        didSet {
            if mode != oldValue {
                draftSession = nil
                isPublicFestivalMesh = false
            }
        }
    }
    private(set) var isPublicFestivalMesh = false
    private(set) var draftSession: GroupSession?
    private(set) var scannedInvite: GroupSessionInvite?
    var inviteText = ""
    var errorMessage: String?
    var isShowingQR: Bool { draftSession != nil }

    init(sessionStore: SessionStore, onActivate: (@MainActor (GroupSession) -> Void)? = nil) {
        self.sessionStore = sessionStore
        self.onActivate = onActivate ?? { sessionStore.activeSession = $0 }
    }

    var canPerformPrimaryAction: Bool {
        if isPublicFestivalMesh { return form.hasValidInitials }
        return mode == .create ? form.canGenerateQR : form.hasValidInitials && scannedInvite != nil
    }

    func showQRPreview() {
        guard mode == .create, form.canGenerateQR else { return }
        do {
            draftSession = try GroupSessionFactory.create(
                name: form.trimmedSessionName,
                initials: form.initials,
                colorCode: form.profileColor.wireColorCode
            )
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func activateLocalSession() {
        guard !sessionStore.hasActiveSession,
              canPerformPrimaryAction,
              mode == .join || isShowingQR else { return }

        do {
            let session: GroupSession
            if isPublicFestivalMesh, let draftSession {
                session = draftSession
            } else if mode == .join, let invite = scannedInvite {
                session = try GroupSessionFactory.join(
                    invite: invite, initials: form.initials,
                    colorCode: form.profileColor.wireColorCode
                )
            } else if let draftSession {
                session = draftSession
            } else { return }
            sessionStore.pendingInvite = nil
            errorMessage = nil
            onActivate(session)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func receiveInvite(_ invite: GroupSessionInvite) {
        isPublicFestivalMesh = false
        mode = .join
        scannedInvite = invite
        form.sessionName = invite.sessionName
        errorMessage = nil
    }

    func handleScannedCode(_ text: String) {
        guard let invite = GroupSession.parseInvite(from: text) else {
            errorMessage = PairingError.invalidInvite.localizedDescription
            return
        }
        receiveInvite(invite)
    }

    func useInviteLink() {
        handleScannedCode(inviteText)
    }

    func preparePublicFestivalMesh() {
        guard form.hasValidInitials else { return }
        form.sessionName = "Festival Mesh"
        mode = .join
        scannedInvite = nil
        isPublicFestivalMesh = true
        draftSession = GroupSession(localInitials: form.initials, localColorCode: form.profileColor.wireColorCode)
        errorMessage = nil
    }

    func cancelPublicFestivalAgreement() {
        guard isPublicFestivalMesh else { return }
        isPublicFestivalMesh = false
        draftSession = nil
    }
}

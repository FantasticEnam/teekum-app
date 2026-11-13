//
//  AppRootView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 02/11/26.
//

import SwiftUI

struct AppRootView: View {
    let sessionStore: SessionStore
    var controller: SessionController?

    var body: some View {
        if sessionStore.hasActiveSession {
            OrbitMapView(sessionStore: sessionStore, location: controller?.location,
                chat: controller?.chat, sos: controller?.sos, meetingService: controller?.meeting,
                relayPolicy: controller?.relayPolicy, relayState: controller?.relayState ?? .init(mode: .disabled),
                diagnostics: { controller?.diagnostics }, notifications: controller?.notifications,
                onLeaveGroup: controller.map { owner in { owner.leave() } })
        } else {
            NavigationStack {
                GroupPairingView(sessionStore: sessionStore, onActivate: activateSession)
            }
        }
    }

    private var activateSession: (@MainActor (GroupSession) -> Void)? {
        guard let controller else { return nil }
        return { controller.activate($0) }
    }
}

#Preview {
    AppRootView(sessionStore: .preview)
}

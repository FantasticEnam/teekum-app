//
//  AppRootView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 02/11/26.
//

import SwiftUI

struct AppRootView: View {
    let sessionStore: SessionStore

    var body: some View {
        if sessionStore.hasActiveSession {
            OrbitMapView(sessionStore: sessionStore)
        } else {
            NavigationStack {
                GroupPairingView(sessionStore: sessionStore)
            }
        }
    }
}

#Preview {
    AppRootView(sessionStore: .preview)
}

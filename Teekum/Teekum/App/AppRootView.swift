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
            Text("Pairing View Placeholder (Developer A)")
        }
    }
}

#Preview {
    AppRootView(sessionStore: .preview)
}

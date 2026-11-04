//
//  TeekumApp.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 27/10/26.
//

import SwiftUI

@main
struct TeekumApp: App {
    @State private var sessionStore = SessionStore.preview // Gunakan .preview sementara agar langsung masuk MainMapView
    
    var body: some Scene {
        WindowGroup {
            MainMapView()
        }
    }
}

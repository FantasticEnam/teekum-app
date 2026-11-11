//
//  TeekumApp.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 27/10/26.
//

import SwiftUI

@main
struct TeekumApp: App {
    @State private var controller = SessionController()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            AppRootView(sessionStore: controller.store, controller: controller)
                .preferredColorScheme(.dark)
                .disabled(controller.isTransitioning)
                .overlay(alignment: .top) {
                    if let message = controller.errorMessage {
                        VStack {
                            Text(message).font(.subheadline)
                            Button("Dismiss") { controller.errorMessage = nil }
                        }
                        .padding()
                        .background(Color.blackCard, in: .rect(cornerRadius: 16))
                        .padding()
                    }
                }
                .task { await controller.restore() }
                .onOpenURL(perform: controller.handleURL)
                .alert("Join another group?", isPresented: $controller.isShowingGroupSwitch) {
                    Button("Cancel", role: .cancel, action: controller.cancelPendingInvite)
                    Button("Leave and join", role: .destructive, action: controller.joinPendingInvite)
                } message: {
                    Text("This leaves your current group and clears its conversation before opening the invite.")
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        controller.sos.recordUserInteraction()
                        Task { await controller.updatePower() }
                    }
                }
        }
    }
}

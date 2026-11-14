//
//  SOSEdgeGlowView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 12/11/26.
//

import SwiftUI

struct SOSEdgeGlowView: View {
    let sos: SOSViewModel?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if sos?.showsEdgeGlow == true {
            Group {
                if reduceMotion {
                    glow.opacity(0.5)
                } else {
                    glow.phaseAnimator([0.1, 0.5]) { glow, opacity in
                        glow.opacity(opacity)
                    } animation: { _ in
                        .easeInOut(duration: 0.8)
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true) 
        }
    }

    private var glow: some View {
        Rectangle()
            .strokeBorder(Color.alertRed, lineWidth: 44)
            .blur(radius: 30)
    }
}
 
#if DEBUG
#Preview("SOS edge glow") {
    OrbitMapView(sessionStore: .preview, sos: .preview)
        .preferredColorScheme(.dark)
}
#endif

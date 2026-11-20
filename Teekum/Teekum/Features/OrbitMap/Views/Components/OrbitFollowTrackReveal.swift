//
//  OrbitFollowTrackReveal.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import SwiftUI

nonisolated struct OrbitFollowTrackReveal: ViewModifier, Animatable {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content.mask(alignment: .leading) {
            GeometryReader { geometry in
                let feather = min(20, geometry.size.width)
                let edge = (geometry.size.width + feather) * min(1, max(0, progress))

                HStack(spacing: 0) {
                    Rectangle().fill(.white).frame(width: max(0, edge - feather))
                    LinearGradient(colors: [.white, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: feather)
                }
                .offset(x: min(0, edge - feather))
            }
        }
    }
}

#Preview("Follow Track Reveal") {
    @Previewable @State var isRevealed = true

    VStack(spacing: 16) {
        OrbitFollowTrack(nickname: "NIC", distance: 12)
            .frame(height: 44)
            .modifier(OrbitFollowTrackReveal(progress: isRevealed ? 1 : 0))
        Button(isRevealed ? "Hide track" : "Reveal track") {
            withAnimation(.smooth(duration: 0.35)) { isRevealed.toggle() }
        }
    }
    .frame(width: 240)
    .padding(24)
    .background(Color.blackCard)
    .preferredColorScheme(.dark)
}

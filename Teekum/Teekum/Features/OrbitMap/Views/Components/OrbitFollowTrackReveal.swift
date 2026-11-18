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

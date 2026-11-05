//
//  OrbitSceneView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitSceneView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let baseSize = min(size.width, size.height)
            let outerRadius = baseSize * 1.55 / 2

            ZStack {
                StarfieldView()

                RadialGradient(
                    stops: [
                        .init(
                            color: .clear,
                            location: 0
                        ),
                        .init(
                            color: .black.opacity(0.15),
                            location: 0.65
                        ),
                        .init(
                            color: .black.opacity(0.75),
                            location: 1
                        )
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: outerRadius
                )
            }
            .frame(width: size.width, height: size.height)
            .overlay {
                ZStack {
                    ForEach([0.55, 1.1, 1.55], id: \.self) { scale in
                        Circle()
                            .stroke(
                                .white.opacity(0.4),
                                lineWidth: 0.5
                            )
                            .frame(
                                width: baseSize * scale,
                                height: baseSize * scale
                            )
                    }
                }
                .allowsHitTesting(false)
            }
            .clipped()
        }
        .background(.black)
    }
}

#Preview {
    OrbitSceneView()
}

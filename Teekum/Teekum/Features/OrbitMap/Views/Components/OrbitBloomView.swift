//
//  OrbitBloomView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct OrbitBloomView: View {
    let radius: CGFloat
    var rotation: Angle = .zero

    var body: some View {
        let angle = rotation.radians + .pi * 0.3
        let x = radius * CGFloat(cos(angle))
        let y = radius * CGFloat(sin(angle))

        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .orange.opacity(0.7),
                            .orange.opacity(0.2),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 42
                    )
                )
                .frame(width: 84, height: 84)
                .offset(x: -x, y: -y)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                .blue.opacity(0.65),
                                .blue.opacity(0.2),
                                .clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 42
                        )
                    )
                    .frame(width: 84, height: 84)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.creamProfile.opacity(0.8), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 22
                        )
                    )
                    .frame(width: 44, height: 44)
                    .offset(x: -8, y: -8)
            }
            .offset(x: x, y: y)
        }
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    OrbitBloomView(radius: 150, rotation: .degrees(0))
        .frame(width: 350, height: 350)
        .background(.black)
}

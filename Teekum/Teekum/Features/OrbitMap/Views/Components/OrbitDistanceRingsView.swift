//
//  OrbitDistanceRingsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import SwiftUI

struct OrbitDistanceRingsView: View {
    let scale: OrbitRingScale

    var body: some View {
        ZStack {
            ForEach(scale.distances, id: \.self) { distance in
                let diameter = scale.radius(for: distance) * 2
                Circle()
                    .stroke(.white.opacity(0.4), lineWidth: 0.5)
                    .frame(width: diameter, height: diameter)
                    .overlay(alignment: .bottom) {
                        Text(distance.formattedDistance(spaced: false))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.55))
                            .fixedSize()
                            .alignmentGuide(.bottom) { dimensions in
                                dimensions[.top] - 6
                            }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Distance rings")
        .accessibilityValue(scale.distances.map { $0.formattedDistance() }.joined(separator: ", "))
    }
}

#Preview("5 m, 10 m, 15 m") {
    OrbitDistanceRingsView(scale: .init(range: 15, radius: 160))
        .frame(width: 320, height: 480)
        .background(.black)
        .clipped()
}

#Preview("Adaptive intervals when zoomed out") {
    OrbitDistanceRingsView(scale: .init(range: 120, radius: 160))
        .frame(width: 320, height: 480)
        .background(.black)
        .clipped()
}

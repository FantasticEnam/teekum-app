//
//  OrbitFollowTrack.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import SwiftUI

struct OrbitFollowTrack: View {
    let nickname: String
    let distance: Double?

    @State private var progress = OrbitFollowProgress()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let fraction = distance.map { progress.fraction(remaining: $0) }
        let measurement = distance?.formattedDistance(spaced: false)
        GeometryReader { geometry in
            let dotSize: CGFloat = 7
            let dotTravel = max(0, geometry.size.width - dotSize)

            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(fraction == nil ? 0.3 : 1))
                    .frame(height: 4)

                if let fraction {
                    let offset = dotTravel * CGFloat(fraction)
                    Rectangle()
                        .fill(Color.buttonPrimary)
                        .frame(width: offset + dotSize / 2, height: 4)
                    Circle()
                        .fill(Color.buttonPrimary)
                        .frame(width: dotSize, height: dotSize)
                        .offset(x: offset)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(reduceMotion ? nil : .smooth(duration: 0.35), value: fraction)
        }
        .frame(height: 7)
        .overlay(alignment: .top) {
            Group {
                if let measurement {
                    Text("\(measurement) to \(nickname)")
                        .contentTransition(reduceMotion ? .identity : .numericText())
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: measurement)
                } else {
                    Text("Waiting for location")
                }
            }
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .offset(y: 10)
        }
        .frame(maxHeight: .infinity)
        .onChange(of: distance, initial: true) { _, distance in
            progress.record(distance)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Distance progress and waiting for location") {
    @Previewable @State var distance = 12.0

    VStack(spacing: 16) {
        OrbitFollowTrack(nickname: "NIC", distance: distance)
            .frame(height: 44)
        Slider(value: $distance, in: 0...12)
            .accessibilityLabel("Distance in meters")
        OrbitFollowTrack(nickname: "NIC", distance: nil)
            .frame(height: 44)
    }
    .frame(width: 240)
    .padding(24)
    .background(Color.blackCard)
    .preferredColorScheme(.dark)
}

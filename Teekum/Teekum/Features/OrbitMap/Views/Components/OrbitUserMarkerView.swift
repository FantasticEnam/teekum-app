//
//  OrbitUserMarkerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct OrbitUserMarkerView: View {
    let color: Color
    var heading: Angle? = nil
    var isEmergency = false
    var isTargetSelected = false
    var batteryLevel: Float?
    @ScaledMetric(relativeTo: .caption) private var size: CGFloat = 36

    var body: some View {
        Circle()
            .fill(isEmergency ? Color.alertRed : color)
            .frame(width: size, height: size)
            .overlay {
                Text("YOU")
                    .font(.custom("Helvetica", size: 13, relativeTo: .caption).bold())
                    .foregroundStyle(.black)
            }
            .overlay { directionArrow }
            .overlay(alignment: .bottom) {
                OrbitBatteryIndicatorView(batteryLevel: batteryLevel)
                    .offset(y: 14)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your position")
            .accessibilityValue(
                isEmergency ? "SOS active" : (heading == nil ? "Direction unavailable" : "Direction available")
            )
            .accessibilityHint(OrbitBatteryIndicatorView.percentage(for: batteryLevel).map {
                Text("Low battery, \($0)")
            } ?? Text(""))
    }

    @ViewBuilder
    private var directionArrow: some View {
        if let heading {
            Image(systemName: "location.north.fill")
                .font(.system(size: isTargetSelected ? 30 : 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(
                    width: isTargetSelected ? 120 : 90,
                    height: isTargetSelected ? 120 : 90,
                    alignment: .top
                )
                .rotationEffect(heading)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

#Preview("User Marker States") {
    HStack(spacing: 60) {
        // 1. Normal
        OrbitUserMarkerView(color: .yellowProfile, heading: .degrees(0), batteryLevel: 0.1)

        // 2. SOS Emergency
        OrbitUserMarkerView(color: .yellowProfile, heading: .degrees(0), isEmergency: true)
    }
    .padding(100)
    .background(.black)
}

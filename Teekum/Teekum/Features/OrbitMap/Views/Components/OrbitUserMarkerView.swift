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

    var body: some View {
        Circle()
            .fill(isEmergency ? Color.alertRed : color)
            .frame(width: 30, height: 30)
            .overlay {
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
                }
            }
            .overlay(alignment: .bottom) {
                Text("YOU")
                    .font(.custom("Futura", size: 13, relativeTo: .caption))
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(isEmergency ? Color.alertRed : .black, in: .rect(cornerRadius: 6))
                    .fixedSize()
                    .offset(y: 40)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Your position")
            .accessibilityValue(
                isEmergency ? "SOS active" : (heading == nil ? "Direction unavailable" : "Direction available")
            )
    }
}

#Preview("User Marker States") {
    HStack(spacing: 60) {
        // 1. Normal
        OrbitUserMarkerView(color: .yellowProfile, heading: .degrees(0))

        // 2. SOS Emergency
        OrbitUserMarkerView(color: .yellowProfile, heading: .degrees(0), isEmergency: true)
    }
    .padding(100)
    .background(.black)
}

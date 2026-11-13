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

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .shadow(color: color, radius: 8)
            .overlay {
                if let heading {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(
                            width: 90,
                            height: 90,
                            alignment: .top
                        )
                        .rotationEffect(heading)
                }
            }
            .overlay(alignment: .bottom) {
                Text("YOU")
                    .font(.custom("Futura", size: 13, relativeTo: .caption))
                    .fontWeight(.semibold)
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

#Preview {
    OrbitUserMarkerView(color: .yellowProfile, heading: .degrees(0))
        .padding(100)
        .background(.black)
}

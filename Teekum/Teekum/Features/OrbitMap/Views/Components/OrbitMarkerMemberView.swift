//
//  OrbitMarkerMemberView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct OrbitMemberMarkerView: View {
    let initials: String
    let color: Color
    var isSelected = false
    var isEmergency = false
    @ScaledMetric(relativeTo: .caption) var size: CGFloat = 36
    var showsBloom = false
    var batteryLevel: Float?
    var heading: Angle?
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: showsBloom ? 6 : 0)
            .shadow(color: showsBloom ? color.opacity(0.7) : .clear, radius: 10)
            .overlay {
                if !showsBloom && (isSelected || isEmergency) {
                    Circle()
                        .strokeBorder(isEmergency ? Color.alertRed : Color.buttonPrimary, lineWidth: 2)
                        .padding(-4)
                }
            }
            .overlay {
                if !showsBloom {
                    Text(initials)
                        .font(.custom("Helvetica", size: 13, relativeTo: .caption).bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.black)
                        .padding(3)
                }
            }
            .overlay(alignment: .bottom) {
                if !showsBloom {
                    OrbitBatteryIndicatorView(batteryLevel: batteryLevel)
                        .offset(y: 14)
                }
            }
            .overlay {
                if !showsBloom, let heading {
                    let width = size * 0.4
                    let height = size * 0.25
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        path.addLine(to: CGPoint(x: width / 2, y: 0))
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.addLine(to: CGPoint(x: width / 2, y: height * 0.65))
                        path.closeSubpath()
                    }
                        .fill(color)
                        .frame(width: width, height: height)
                        .offset(y: -size / 2 - height / 2 - 2)
                        .rotationEffect(heading)
                        .accessibilityHidden(true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Member \(initials)")
            .accessibilityHint(OrbitBatteryIndicatorView.percentage(for: batteryLevel).map {
                Text("Low battery, \($0)")
            } ?? Text(""))
    }
}

#Preview("Outside the rings shows bloom only") {
    HStack(spacing: 48) {
        OrbitMemberMarkerView(initials: "ALX", color: .blue, heading: .degrees(135))
        ZStack {
            OrbitMemberMarkerView(initials: "ADI", color: .yellowProfile, isSelected: true,
                showsBloom: true, batteryLevel: 0.05, heading: .degrees(0))
                .offset(x: -8)
            OrbitMemberMarkerView(initials: "HSN", color: .greenProfile, isEmergency: true,
                showsBloom: true, batteryLevel: 0.1, heading: .degrees(90))
                .offset(x: 8)
        }
    }
    .padding(48)
    .background(.black)
}

#Preview("Low battery markers") {
    HStack(spacing: 64) {
        OrbitMemberMarkerView(initials: "HSN", color: .greenProfile, batteryLevel: 0.1, heading: .degrees(315))
        OrbitMemberMarkerView(initials: "NIC", color: .redProfile, isEmergency: true,
            batteryLevel: 0.05, heading: .degrees(90))
    }
    .padding(80)
    .background(.black)
}

#Preview("Normal and SOS markers") {
    HStack(spacing: 64) {
        OrbitMemberMarkerView(initials: "AYU", color: .pinkProfile, heading: .degrees(0))
        OrbitMemberMarkerView(initials: "NIC", color: .redProfile, isEmergency: true, heading: .degrees(240))
    }
    .padding(80)
    .background(.black)
}

#Preview("Friend heading directions") {
    HStack(spacing: 32) {
        OrbitMemberMarkerView(initials: "AYU", color: .yellowProfile, heading: .degrees(0))
        OrbitMemberMarkerView(initials: "NIC", color: .pinkProfile, heading: .degrees(240))
        OrbitMemberMarkerView(initials: "ADI", color: .redProfile, isSelected: true, heading: .degrees(45))
    }
    .padding(40)
    .background(.black)
}

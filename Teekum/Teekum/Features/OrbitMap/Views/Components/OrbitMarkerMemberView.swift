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
    var size: CGFloat = 30
    var showsBloom = false
    var lowBatteryPercentage: String?

    private var showsPointer: Bool { isEmergency || isSelected || lowBatteryPercentage != nil }
    private var bubbleColor: Color { isEmergency ? .alertRed : (isSelected ? .yellowProfile : .black) }
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: showsBloom ? 4 : 0)
            .shadow(color: showsBloom ? color.opacity(0.7) : .clear, radius: 10)
            .overlay {
                if isSelected || isEmergency {
                    Circle()
                        .strokeBorder(isEmergency ? Color.alertRed : Color.yellowProfile, lineWidth: 2)
                        .padding(-4)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: -2) {
                    VStack(spacing: 1) {
                        Text(initials)
                            .font(.custom("Helvetica", size: isSelected ? 16 : 13, relativeTo: .caption))
                            .foregroundStyle(isSelected && !isEmergency ? .black : .white)
                        if let lowBatteryPercentage {
                            Label(lowBatteryPercentage, systemImage: "bolt.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(isSelected && !isEmergency ? .black : .yellowProfile)
                        }
                    }
                    .padding(.horizontal, isSelected ? 14 : 10)
                    .padding(.vertical, isSelected ? 8 : 6)
                    .background(bubbleColor, in: .rect(cornerRadius: isSelected ? 8 : 6))
                    
                    if showsPointer {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: isSelected ? 13 : 10))
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(bubbleColor)
                    }
                }
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + (showsPointer ? 2 : 12) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Member \(initials)")
    }
}

#Preview("Low battery markers") {
    HStack(spacing: 64) {
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile, lowBatteryPercentage: "20%")
        OrbitMemberMarkerView(initials: "NIC", color: .peachProfile, isEmergency: true, lowBatteryPercentage: "12%")
    }
    .padding(80)
    .background(.black)
}

#Preview("Normal and SOS markers") {
    HStack(spacing: 64) {
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile)
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile, isSelected: true)
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile, isEmergency: true)
    }
    .padding(80)
    .background(.black)
}

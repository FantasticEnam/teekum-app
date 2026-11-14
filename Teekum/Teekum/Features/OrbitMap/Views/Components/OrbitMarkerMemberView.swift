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
                    Text(initials)
                        .font(.custom("Futura", size: isSelected ? 16 : 13, relativeTo: .caption))
                        .foregroundStyle((isSelected && !isEmergency) ? .black : .white)
                        .padding(.horizontal, isSelected ? 14 : 10)
                        .padding(.vertical, isSelected ? 8 : 6)
                        .background(
                                                    isEmergency ? Color.alertRed : (isSelected ? Color.yellowProfile : .black),
                                                    in: .rect(cornerRadius: isSelected ? 8 : 6)
                                                )
                    
                    if isEmergency || isSelected {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: isSelected ? 13 : 10))
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(isEmergency ? Color.alertRed : (isSelected ? Color.yellowProfile : .black))
                    }
                }
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + (isEmergency || isSelected ? 2 : 12) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Member \(initials)")
    }
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

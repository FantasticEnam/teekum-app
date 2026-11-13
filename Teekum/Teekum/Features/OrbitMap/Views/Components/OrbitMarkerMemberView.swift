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
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .shadow(color: color.opacity(0.8), radius: 8)
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(Color.yellowProfile, lineWidth: 2)
                        .padding(-4)
                }
            }
            .overlay(alignment: .top) {
                VStack(spacing: -2) {
                    Text(initials)
                        .font(.custom("Charter-Roman", size: 13, relativeTo: .caption))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isEmergency ? Color.alertRed : .black, in: .rect(cornerRadius: 6))
                    if isEmergency {
                        Image(systemName: "triangle.fill")
                            .font(.system(size: 10))
                            .rotationEffect(.degrees(180))
                            .foregroundStyle(Color.alertRed)
                    }
                }
                .fixedSize()
                .shadow(color: isEmergency ? .alertRed.opacity(0.65) : .clear, radius: 12)
                .alignmentGuide(.top) { $0[.bottom] + (isEmergency ? 1 : 12) }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Member \(initials)")
    }
}

#Preview("Normal and SOS markers") {
    HStack(spacing: 64) {
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile)
        OrbitMemberMarkerView(initials: "AYU", color: .orangeProfile, isEmergency: true)
    }
    .padding(80)
    .background(.black)
}

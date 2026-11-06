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
    
    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 30, height: 30)
            .shadow(color: color.opacity(0.5), radius: 8)
            .overlay(alignment: .top) {
                Text(initials)
                    .font(.custom("Charter-Roman", size: 13, relativeTo: .caption))
//                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black, in: .rect(cornerRadius: 6))
                    .fixedSize()
                    .offset(y: -40)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Member \(initials)")
    }
}

#Preview {
    OrbitMemberMarkerView(
        initials: "ALX",
        color: .peachProfile
    )
    .padding(80)
    .background(.black)
}

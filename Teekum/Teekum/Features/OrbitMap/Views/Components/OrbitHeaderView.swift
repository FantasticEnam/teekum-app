//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    let groupName: String
    var onSettings: () -> Void = {}

    var body: some View {
        Text(groupName)
            .bold()
            .font(.custom("Helvetica", size: 20, relativeTo: .title2))
            .lineLimit(1)
            .padding(.horizontal, 68)
            .frame(maxWidth: .infinity, minHeight: 60)
            .overlay(alignment: .leading) {
                Button(action: onSettings) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .contentShape(.circle)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")
            }
    }
}

#Preview {
    OrbitHeaderView(groupName: "Fantasix")
        .padding(.horizontal, 24)
        .preferredColorScheme(.dark)
}

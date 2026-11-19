//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    let groupName: String
    let roomCount: Int
    var onSettings: () -> Void = {}

    var body: some View {
        VStack(spacing: 3) {
            Text(groupName)
                .bold()
                .font(.custom("Helvetica", size: 20, relativeTo: .title2))
                .lineLimit(1)

            (roomCount == 1 ? Text("1 Person") : Text("\(roomCount) Persons"))
                .font(.subheadline)
                .foregroundStyle(Color.buttonPrimary)
        }
        .accessibilityElement(children: .combine)
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

#Preview("Orbit group and person count") {
    OrbitHeaderView(groupName: "Fantasix", roomCount: 5)
        .padding(.horizontal, 24)
        .background(.black)
        .preferredColorScheme(.dark)
}

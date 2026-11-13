//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    let groupName: String
    let onOpenMap: () -> Void
    var onSettings: () -> Void = {}

    var body: some View {
        HStack {
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Settings")
            
            Spacer()
            
            Text(groupName)
                .bold()
                .font(.custom("Futura", size: 20, relativeTo: .title2))
                .lineLimit(1)
            
            Spacer()
            
            Button(action: onOpenMap) {
                Image(systemName: "map.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open meeting point map")
        }
    }
}

#Preview {
    OrbitHeaderView(groupName: "Fantasix", onOpenMap: {})
}

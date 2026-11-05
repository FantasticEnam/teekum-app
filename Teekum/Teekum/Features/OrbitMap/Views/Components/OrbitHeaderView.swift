//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    var body: some View {
        HStack {
            Button {
                print("Settings Tapped")
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Settings")
            
            Spacer()
            
            Text("Group Name")
                .bold()
                .font(.custom("Charter-Roman", size: 22, relativeTo: .title2))
                .lineLimit(1)
            
            Spacer()
            
            Button {
                print("Map Tapped")
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.glass)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open meeting point map")
        }
    }
}

#Preview {
    OrbitHeaderView()
}

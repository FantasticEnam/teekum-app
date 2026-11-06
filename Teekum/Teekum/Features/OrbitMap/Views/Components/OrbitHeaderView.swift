//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    @State private var isShowingMap: Bool = false
    
    var body: some View {
        HStack {
            Button {
                print("Settings Tapped")
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 42, height: 42)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Settings")
            
            Spacer()
            
            Text("Group Name")
                .bold()
                .font(.custom("Charter-Roman", size: 20, relativeTo: .title2))
                .lineLimit(1)
            
            Spacer()
            
            Button {
                isShowingMap = true
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 30, weight: .semibold))
//                    .frame(width: 62, height: 62)
            }
            .buttonStyle(.glass)
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open meeting point map")
            
            .fullScreenCover(isPresented: $isShowingMap) {
                MainMapView()
            }
        }
    }
}

#Preview {
    OrbitHeaderView()
}

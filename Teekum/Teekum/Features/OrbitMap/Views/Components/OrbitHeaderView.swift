//
//  OrbitHeaderView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitHeaderView: View {
    // 1️⃣ Tambahkan state ini untuk kontrol buka/tutup peta
    @State private var isShowingMap: Bool = false
    
    var body: some View {
        HStack {
            Button {
                print("Settings Tapped")
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 30, weight: .semibold))
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
            
            // 2️⃣ Tombol Map
            Button {
                isShowingMap = true // 👈 Buka peta saat ditekan
            } label: {
                Image(systemName: "map.fill")
                    .font(.system(size: 30, weight: .semibold))
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .controlSize(.large)
            .accessibilityLabel("Open meeting point map")
            // 3️⃣ Munculkan MainMapView secara full screen
            .fullScreenCover(isPresented: $isShowingMap) {
                MainMapView()
            }
        }
    }
}

#Preview {
    OrbitHeaderView()
}

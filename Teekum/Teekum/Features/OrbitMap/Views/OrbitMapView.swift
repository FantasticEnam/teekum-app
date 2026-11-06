//
//  OrbitMapView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct OrbitMapView: View {
    @State private var isPanelPresented = false
    
    var body: some View {
        ZStack() {
            Color.black
                .ignoresSafeArea()
            
            OrbitSceneView(bloomRotation: .degrees(5))
                .ignoresSafeArea()
            
            VStack(alignment: .leading) {
                OrbitHeaderView()
                
                Spacer()
                OrbitControlsView(
                    onSOS: {
                        print("SOS requested")
                    },
                    onExpand: {
                        isPanelPresented = true
                    }
                )
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    OrbitMapView()
}

// xcode: set sdk=iOS

//
//  MapPointPinView.swift
//  
//
//  Created by Adiat Rahman on 06/11/26.
//

import SwiftUI

public struct MapPointPinView: View {
    public var title: String = "Meeting Point"
    
    public init(title: String = "Meeting Point") {
        self.title = title
    }
    
    public var body: some View {
        VStack(spacing: 3){
            VStack(spacing: -3) {
                // Meeting Point Text
                Text(title)
                    .font(.custom("Helvetica", size: 14).weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.yellow)
                    .clipShape(Capsule())
                Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.yellow)
            }
            // Pin
            Image("MeetPoint")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.1) ,radius: 3)
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        MapPointPinView()
    }
}

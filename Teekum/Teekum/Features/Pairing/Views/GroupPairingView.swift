//
//  GroupPairingView.swift
//  Teekum
//
//  Created by Ari Hasan on 02/11/26.
//

import SwiftUI

struct GroupPairingView: View {
    var body: some View {
        VStack{
            Image("teekum_1")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 23)
            
            Image("eye_fix")
                .resizable()
                .scaledToFit()
                .frame(width: 130, height: 60)
                .padding(.bottom, 20)
            
            Text("Here's Your Room")
                .font(.title2)
                .bold()
            Text("Share the QR")
                .font(.title2)
                .bold()
        }

    }
}

#Preview {
    GroupPairingView()
}

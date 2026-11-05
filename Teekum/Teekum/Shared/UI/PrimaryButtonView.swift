//
//  PrimaryButtonView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct PrimaryButtonView: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Charter-Bold", size: 16, relativeTo: .headline))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 62)
                .background(Color.yellowProfile, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PrimaryButtonView(title: "Generate QR", action: {})
        .padding(24)
        .background(.black)
}

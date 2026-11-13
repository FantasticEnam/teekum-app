//
//  PrimaryButtonView.swift
//  Teekum
//
//  Created by Ari Hasan on 05/11/26.
//

import SwiftUI

struct PrimaryButtonView: View {
    let title: LocalizedStringKey
    var trailingSystemImage: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                if let trailingSystemImage {
                    Image(systemName: trailingSystemImage)
                        .accessibilityHidden(true)
                }
            }
            .font(.custom("Futura", size: 16, relativeTo: .headline))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity, minHeight: 50)
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

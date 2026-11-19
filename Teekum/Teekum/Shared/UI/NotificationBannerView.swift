//
//  NotificationBannerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import SwiftUI

struct NotificationBannerView: View {
    let title: String
    let message: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.bold())
                Text(message).font(.subheadline).lineLimit(3)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(white: 0.26), in: .rect(cornerRadius: 32))
        .contentShape(.rect(cornerRadius: 32))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Meeting point and Follow") {
    VStack {
        NotificationBannerView(title: "Meeting Point Set!", message: "ADI set up a new meeting point!", icon: "mappin.and.ellipse")
        NotificationBannerView(title: "ADI followed you", message: "Stay where you are so they can find you.", icon: "person.2.fill")
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}

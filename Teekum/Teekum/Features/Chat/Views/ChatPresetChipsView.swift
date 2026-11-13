//
//  ChatPresetChipsView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatPresetChipsView: View {
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(ChatMessagePayload.standardPresets, id: \.self) { preset in
                    Button(preset) { onSelect(preset) }
                        .buttonStyle(.bordered)
                        .tint(.yellowProfile)
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 8)
    }
}

#Preview("Preset replies") {
    ChatPresetChipsView { _ in }
        .background(.black)
        .preferredColorScheme(.dark)
}

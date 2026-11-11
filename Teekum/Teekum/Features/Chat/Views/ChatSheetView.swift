//
//  ChatSheetView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatSheetView: View {
    let viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.messages.isEmpty {
                    ContentUnavailableView("Group chat", systemImage: "bubble.left.and.bubble.right", description: Text("Send a short message to your group."))
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubbleView(message: message)
                            }
                        }
                        .padding()
                    }
                    .defaultScrollAnchor(.bottom)
                }
                ChatPresetChipsView(onSelect: viewModel.updateDraft)
                ChatComposerView(viewModel: viewModel)
            }
            .background(.black)
            .navigationTitle("Group chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

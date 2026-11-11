//
//  ChatSheetView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatSheetView: View {
    let viewModel: ChatViewModel
    let sessionStore: SessionStore
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
                                ChatMessageBubbleView(message: message, profileColor: sessionStore.profileColor)
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

#if DEBUG
#Preview("Group conversation") {
    @Previewable @State var viewModel = ChatViewModel.preview()

    ChatSheetView(viewModel: viewModel, sessionStore: .preview)
        .task { await viewModel.start() }
}

extension ChatViewModel {
    static func preview(draft: String = "") -> ChatViewModel {
        let session = SessionStore.preview.activeSession
        let viewModel = ChatViewModel(service: ChatPreviewService(), sessionProvider: { session })
        viewModel.draftText = draft
        return viewModel
    }
}

actor ChatPreviewService: ChatMessagingService {
    static let sampleMessages = [
        ChatMessage(sequenceNumber: 1, senderInitials: "ADI", text: "Meet at Gate 2", isLocalSender: false),
        ChatMessage(sequenceNumber: 2, senderInitials: "DAF", text: "On my way",
            recipientStates: [
                "ADI": .deliveredToRecipient(timestamp: .now, rssi: nil),
                "HAS": .relayedByMesh(hops: 1, relayPeerId: "NIC")
            ],
            deliveryState: .relayedByMesh(hopCount: 1), isLocalSender: true)
    ]

    let currentBatteryLevel: Float = 1
    let isLowPowerMode = false
    let isSurvivalMode = false
    let timingConfig = MeshTimingConfiguration()
    private var messages = ChatPreviewService.sampleMessages

    func sendMessage(text: String, targetRecipients: [String]?) -> ChatMessage {
        let message = ChatMessage(sequenceNumber: UInt32(messages.count + 1),
            senderInitials: "DAF", text: text, deliveryState: .forwardedToNextHop, isLocalSender: true)
        messages.append(message)
        return message
    }

    func activeMessages() -> [ChatMessage] { messages }
    func clearHistory() { messages.removeAll() }
    func setOnMessageUpdated(_ handler: (@Sendable (ChatMessage) -> Void)?) {}
    func setBatteryLevel(_ level: Float, isLowPowerMode: Bool) {}
}
#endif

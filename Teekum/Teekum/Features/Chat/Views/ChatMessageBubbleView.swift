//
//  ChatMessageBubbleView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import SwiftUI

struct ChatMessageBubbleView: View {
    let message: ChatMessage
    let profileColor: @MainActor (String) -> MemberColor

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isLocalSender { Spacer(minLength: 24) }
            VStack(alignment: .leading, spacing: 6) {
                Text(message.senderInitials)
                    .font(.caption.bold())
                    .foregroundStyle(profileColor(message.senderInitials).swiftUIColor)
                Text(message.text).font(.body)
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if message.isLocalSender {
                    Text(message.deliverySummaryText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !message.recipientStates.isEmpty {
                        ChatRecipientStatusView(states: message.recipientStates, profileColor: profileColor)
                    }
                }
            }
            .padding(14)
            .background(Color.blackCard, in: .rect(cornerRadius: 18))
            if !message.isLocalSender { Spacer(minLength: 24) }
        }
    }
}

#if DEBUG
#Preview("Sent and received") {
    let store = SessionStore.preview

    VStack(spacing: 16) {
        ForEach(ChatPreviewService.sampleMessages) { message in
            ChatMessageBubbleView(message: message, profileColor: store.profileColor)
        }
    }
    .padding()
    .background(.black)
    .preferredColorScheme(.dark)
}
#endif

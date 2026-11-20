//
//  ChatNotificationBannerView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import SwiftUI

struct ChatNotificationBannerView: View {
    let sender: String
    let message: String
    let onOpen: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        Button(action: onOpen) {
            NotificationBannerView(title: sender, message: message, icon: "message.fill")
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open group chat. Swipe up to dismiss this notification.")
        .accessibilityAction(named: Text("Dismiss notification"), onDismiss)
        .offset(y: reduceMotion ? 0 : dragOffset)
        .opacity(1 - min(-dragOffset / 140, 0.8))
        .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: dragOffset)
        .highPriorityGesture(
            DragGesture(minimumDistance: 10)
                .updating($dragOffset) { value, offset, _ in
                    offset = min(0, value.translation.height)
                }
                .onEnded { value in
                    if Self.dismissesSwipe(value.translation) {
                        onDismiss()
                    }
                }
        )
    }

    static func dismissesSwipe(_ translation: CGSize) -> Bool {
        translation.height <= -30 && -translation.height > abs(translation.width)
    }
}

#Preview("Chat notification") {
    ChatNotificationBannerView(sender: "NIC", message: "I've arrived", onOpen: {}, onDismiss: {})
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black)
        .preferredColorScheme(.dark)
}

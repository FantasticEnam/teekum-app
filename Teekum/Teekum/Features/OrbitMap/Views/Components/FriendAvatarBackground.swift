//
//  FriendAvatarBackground.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 18/11/26.
//

import SwiftUI

struct FriendAvatarBackground: View {
    let color: Color
    let isEmergency: Bool
    var borderWidth: CGFloat = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isEmergency {
            if reduceMotion {
                emergencyAvatar
            } else {
                emergencyAvatar.phaseAnimator([1.0, 0.55]) { avatar, opacity in
                    avatar.opacity(opacity)
                } animation: { _ in .easeInOut(duration: 0.8) }
            }
        } else {
            Circle().strokeBorder(color, lineWidth: borderWidth)
        }
    }

    private var emergencyAvatar: some View {
        Circle()
            .inset(by: 3)
            .fill(Color.alertRed)
            .overlay {
                Circle().strokeBorder(Color.alertRed, lineWidth: 2)
            }
    }
}

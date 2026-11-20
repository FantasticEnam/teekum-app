//
//  HomeOnBoarding.swift
//  Teekum
//
//  Created by Ari Hasan on 19/11/26.
//

import SwiftUI

struct HomeOnBoarding: View {
    enum TargetBounds: PreferenceKey {
        static var defaultValue: [HomeOBViewModels.Step: Anchor<CGRect>] { [:] }

        static func reduce(value: inout Value, nextValue: () -> Value) {
            value.merge(nextValue()) { _, latest in latest }
        }
    }

    let step: HomeOBViewModels.Step
    let targetFrame: CGRect
    let onAdvance: () -> Void
    let onDismiss: () -> Void

    private var instruction: LocalizedStringKey {
        switch step {
        case .nickname: "Fill in with the first 3-letter of your nickname"
        case .groupAction: "Start a new group or join a group by an invite link"
        case .groupName: "Give your group a name"
        case .primaryAction: "Join the group and see who’s there"
        }
    }

    var body: some View {
        let highlight = targetFrame.insetBy(dx: step == .nickname ? -10 : -7, dy: -6)
        let instructionAbove = step == .groupAction || step == .primaryAction
        let cornerRadius: CGFloat = step == .primaryAction ? highlight.height / 2 : 10

        Button(action: onAdvance) {
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    var scrim = Path(CGRect(origin: .zero, size: size))
                    scrim.addRoundedRect(in: highlight, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))
                    context.fill(scrim, with: .color(.black.opacity(0.78)), style: FillStyle(eoFill: true))
                }

                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(Color.buttonPrimary, lineWidth: 1)
                    .frame(width: highlight.width, height: highlight.height)
                    .position(x: highlight.midX, y: highlight.midY)

                Text(instruction)
                    .font(.custom("Helvetica", size: 18, relativeTo: .headline))
                    .bold()
                    .foregroundStyle(Color.buttonPrimary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: step == .nickname ? 260 : 290)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(.top, instructionAbove ? 0 : highlight.maxY + 24)
                    .frame(height: instructionAbove ? max(0, highlight.minY - 20) : nil, alignment: .bottom)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(instruction))
        .accessibilityHint(step == .primaryAction ? Text("Closes onboarding.") : Text("Continues onboarding."))
        .accessibilityAction(named: Text("Dismiss onboarding"), onDismiss)
    }
}

#Preview("Home Onboarding") {
    NavigationStack {
        GroupPairingView(
            sessionStore: SessionStore(),
            homeOnboarding: HomeOBViewModels(defaults: nil)
        )
    }
}

//
//  SOSHoldButtonView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 06/11/26.
//

import SwiftUI

struct SOSHoldButton: View {
    let onHoldCompleted: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    @GestureState private var isPressing = false
    @State private var progress: CGFloat = 0
    @State private var showConfirmation = false
    @State private var hapticTrigger = false

    var body: some View {
        Text("SOS")
            .font(.custom("Charter-Roman", size: 25))
            .bold()
            .foregroundStyle(.white)
            .frame(width: 64, height: 64)
            .background(Color.alertRed, in: .circle)
            .glassEffect(
                .regular.tint(.alertRed),
                in: .circle
            )
            .shadow(
                color: Color.redProfile.opacity(
                    isPressing ? 0.8 : 0.35
                ),
                radius: isPressing ? 20 : 10
            )
            .overlay {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        .white,
                        style: StrokeStyle(
                            lineWidth: 3,
                            lineCap: .round
                        )
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            }
            .contentShape(.circle)
            .gesture(
                LongPressGesture(
                    minimumDuration: MeepoConfiguration.SOS.holdDuration,
                    maximumDistance: 20
                )
                .updating($isPressing) { value, state, _ in
                    state = value
                }
                .onEnded { completed in
                    guard completed else { return }
                    requestSOS()
                }
            )
            .sensoryFeedback(
                .impact(weight: .heavy, intensity: 0.8),
                trigger: hapticTrigger
            )
            // Recreate the recognizer when the app changes state.
            .id(scenePhase)
            .onChange(of: isPressing) { _, pressing in
                withAnimation(
                    .linear(duration: pressing ? MeepoConfiguration.SOS.holdDuration : 0.15)
                ) {
                    progress = pressing ? 1 : 0
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    progress = 0
                    showConfirmation = false
                }
            }
            .onDisappear {
                progress = 0
            }
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("SOS")
            .accessibilityHint(
                "Hold for 1.5 seconds. Activate with VoiceOver to confirm sending an SOS."
            )
            .accessibilityAction {
                showConfirmation = true
            }
            .confirmationDialog(
                "Send an SOS to your group?",
                isPresented: $showConfirmation
            ) {
                Button("Send SOS", role: .destructive) {
                    requestSOS()
                }

                Button("Cancel", role: .cancel) {}
            }
    }

    private func requestSOS() {
        guard scenePhase == .active else { return }

        hapticTrigger.toggle()
        onHoldCompleted()
    }
}

#Preview {
    SOSHoldButton {
        print("SOS requested")
    }
    .padding(40)
    .background(.black)
}

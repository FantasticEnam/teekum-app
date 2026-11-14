//
//  SOSSwipeButtonView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 14/11/26.
//

import SwiftUI

struct SOSSwipeButtonView: View {
    let onSwipeCompleted: () -> Void
    var showsTrack = false

    private static let swipeDistance: CGFloat = 64
    private let buttonSize: CGFloat = 64

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @GestureState private var drag: CGSize?
    @State private var showsHint = false
    @State private var showConfirmation = false
    @State private var hapticTrigger = false

    private var travel: CGFloat {
        min(Self.upwardTravel(drag ?? .zero), Self.swipeDistance)
    }

    var body: some View {
        Color.clear
            .frame(width: buttonSize, height: buttonSize)
            .overlay(alignment: .bottom) {
                if showsTrack || drag != nil || showsHint {
                    track
                }
            }
            .overlay {
                Text("SOS")
                    .font(.custom("Futura", size: 25, relativeTo: .title2).bold())
                    .foregroundStyle(.white)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(Color.alertRed, in: .circle)
                    .glassEffect(.regular.tint(.alertRed), in: .circle)
                    .shadow(color: Color.redProfile.opacity(0.35), radius: 10)
                    .offset(y: -travel)
                    .allowsHitTesting(false)
            }
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .updating($drag) { value, drag, _ in
                        drag = value.translation
                    }
                    .onEnded { value in
                        if Self.completesSwipe(value.translation) {
                            requestSOS()
                        } else {
                            showsHint = true
                        }
                    }
            )
            .id(scenePhase)
            .task(id: showsHint) {
                guard showsHint else { return }
                do { try await Task.sleep(for: .seconds(3)) }
                catch { return }
                showsHint = false
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    showsHint = false
                    showConfirmation = false
                }
            }
            .sensoryFeedback(.impact(weight: .heavy, intensity: 0.8), trigger: hapticTrigger)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("SOS")
            .accessibilityHint("Swipe up to send an SOS, or activate to open a confirmation.")
            .accessibilityAction { showConfirmation = true }
            .confirmationDialog("Send an SOS to your group?", isPresented: $showConfirmation) {
                Button("Send SOS", role: .destructive, action: requestSOS)
                Button("Cancel", role: .cancel) {}
            }
    }

    private var track: some View {
        Capsule()
            .fill(Color.alertRed.opacity(0.55)) 
            .phaseAnimator(
                reduceMotion ? [1.0] : [1.0, 0.55],
                content: { capsule, opacity in capsule.opacity(opacity) },
                animation: { _ in .easeInOut(duration: 1.25) }
            )
            .frame(width: buttonSize, height: buttonSize + Self.swipeDistance)
            .overlay(alignment: .top) {
                if reduceMotion {
                    chevron
                } else {
                    chevron.keyframeAnimator(initialValue: 0.0, repeating: true) { view, progress in
                        view.offset(y: 22 * (1 - progress))
                            .opacity(sin(progress * .pi))
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 1.25)
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var chevron: some View {
        Image(systemName: "chevron.up")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: buttonSize, height: buttonSize)
    }

    static func completesSwipe(_ translation: CGSize) -> Bool {
        upwardTravel(translation) >= swipeDistance
    }

    private static func upwardTravel(_ translation: CGSize) -> CGFloat {
        let distance = -translation.height
        return distance > abs(translation.width) ? distance : 0
    }

    private func requestSOS() {
        guard scenePhase == .active, isEnabled else { return }
        showsHint = false
        hapticTrigger.toggle()
        onSwipeCompleted()
    }
}

#Preview("Swipe to send SOS") {
    SOSSwipeButtonView(onSwipeCompleted: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding()
        .background(.black)
        .preferredColorScheme(.dark)
}

#Preview("SOS swipe track visible") {
    SOSSwipeButtonView(onSwipeCompleted: {}, showsTrack: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding()
        .background(.black)
        .preferredColorScheme(.dark)
}

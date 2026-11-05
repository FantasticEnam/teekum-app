//
//  StarfieldView.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 05/11/26.
//

import SwiftUI

struct StarfieldView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isVisible = false
    @State private var lowPowerMode =
        ProcessInfo.processInfo.isLowPowerModeEnabled

    // Generate once so positions stay stable during redraws.
    private static let stars = (0..<100).map { _ in
        (
            x: CGFloat.random(in: 0...1),
            y: CGFloat.random(in: 0...1),
            radius: CGFloat.random(in: 0.5...1.5),
            opacity: Double.random(in: 0.2...0.65),
            phase: Double.random(in: 0...(2 * .pi)),
            period: Double.random(in: 3...7)
        )
    }

    private var shouldAnimate: Bool {
        isVisible &&
        scenePhase == .active &&
        !reduceMotion &&
        !lowPowerMode
    }

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 50,
                paused: !shouldAnimate
            )
        ) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                for (index, star) in Self.stars.enumerated() {
                    let twinkle = shouldAnimate && index.isMultiple(of: 4)
                        ? 0.65 + 0.35 * sin(
                            time * 2 * .pi / star.period + star.phase
                        )
                        : 1.0

                    let rect = CGRect(
                        x: star.x * size.width - star.radius,
                        y: star.y * size.height - star.radius,
                        width: star.radius * 2,
                        height: star.radius * 2
                    )

                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(
                            .white.opacity(star.opacity * twinkle)
                        )
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .onDisappear {
            isVisible = false
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: .NSProcessInfoPowerStateDidChange
            )
        ) { _ in
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

#Preview {
    StarfieldView()
}

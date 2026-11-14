//
//  DefaultSOSAudioAlerter.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import AudioToolbox
import UIKit

@MainActor
public final class DefaultSOSAudioAlerter: SOSAudioAlerting {
    private var repeatTask: Task<Void, Never>?
    private let interval: Duration
    private let testPulse: (() -> Void)?

    public init() {
        interval = .seconds(2)
        testPulse = nil
    }

    init(interval: Duration, pulse: @escaping () -> Void) {
        self.interval = interval
        testPulse = pulse
    }

    public func triggerEmergencyAlertFeedback() async {
        guard repeatTask == nil else { return }
        playPulse()
        repeatTask = Task { [weak self, interval] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: interval) }
                catch { return }
                guard !Task.isCancelled, let self else { return }
                playPulse()
            }
        }
    }

    public func stopEmergencyAlertFeedback() async {
        repeatTask?.cancel()
        repeatTask = nil
    }

    private func playPulse() {
        if let testPulse {
            testPulse()
            return
        }
        // shortcut: background alerts use the existing iOS notification; this loop plays only while active.
        guard UIApplication.shared.applicationState == .active else { return }
        AudioServicesPlayAlertSound(SystemSoundID(1005))
        AudioServicesPlayAlertSound(kSystemSoundID_Vibrate)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}

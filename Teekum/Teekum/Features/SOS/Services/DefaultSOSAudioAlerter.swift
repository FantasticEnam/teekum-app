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
    private var isReminding = false
    private let interval: Duration
    private let reminderInterval: Duration
    private let testPulse: (() -> Void)?

    public init() {
        interval = .seconds(2)
        reminderInterval = .seconds(90)
        testPulse = nil
    }

    init(interval: Duration, reminderInterval: Duration = .seconds(90), pulse: @escaping () -> Void) {
        self.interval = interval
        self.reminderInterval = reminderInterval
        testPulse = pulse
    }

    public func triggerEmergencyAlertFeedback() async {
        guard repeatTask == nil || isReminding else { return }
        isReminding = false
        playPulse()
        startRepeating(every: interval)
    }

    public func scheduleEmergencyReminder() async {
        guard !isReminding else { return }
        isReminding = true
        startRepeating(every: reminderInterval)
    }

    private func startRepeating(every interval: Duration) {
        repeatTask?.cancel()
        repeatTask = Task { [weak self] in
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
        isReminding = false
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

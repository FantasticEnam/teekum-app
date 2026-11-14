//
//  SOSAudioAlerting.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation

/// Authoritative contract for audio and haptic alert feedback when emergency SOS is triggered or received.
public protocol SOSAudioAlerting: Sendable {
    /// Starts repeating feedback for an unacknowledged emergency.
    func triggerEmergencyAlertFeedback() async

    /// Switches to delayed reminders after the receiver acknowledges the alert.
    func scheduleEmergencyReminder() async
    
    /// Stops any ongoing audio alert or siren loop.
    func stopEmergencyAlertFeedback() async
}

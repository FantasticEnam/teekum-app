//
//  SOSAudioAlerting.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation

/// Authoritative contract for audio and haptic alert feedback when emergency SOS is triggered or received.
public protocol SOSAudioAlerting: Sendable {
    /// Plays the emergency alert tone / siren and triggers strong haptic vibration.
    func triggerEmergencyAlertFeedback()
    
    /// Stops any ongoing audio alert or siren loop.
    func stopEmergencyAlertFeedback()
}

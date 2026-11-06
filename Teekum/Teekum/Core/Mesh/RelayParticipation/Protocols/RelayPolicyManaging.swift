//
//  RelayPolicyManaging.swift
//  Teekum
//
//  Created by Nicho on 06/11/26.
//

import Foundation

public protocol RelayPolicyManaging: Actor {
    /// Current effective policy state.
    func currentState() async -> RelayPolicyState
    
    /// Updates user-selected participation mode (from UI or Lock Screen).
    func setParticipationMode(_ mode: RelayParticipationMode) async
    
    /// Sets timed participation mode for the specified duration (default 30 minutes / 1800s).
    func setTimedParticipation(durationSeconds: TimeInterval) async
    
    /// Promptly halts relaying and drains/cancels queued work.
    func stopRelaying() async
    
    /// Updates hardware power metrics from UIDevice / ProcessInfo.
    func updatePowerMetrics(batteryLevel: Float, isLowPowerMode: Bool) async
    
    /// Evaluates whether forwarding a packet of the given type is currently permitted.
    func canRelay(packetType: PacketType) async -> Bool
}

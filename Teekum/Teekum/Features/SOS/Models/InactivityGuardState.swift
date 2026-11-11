//
//  InactivityGuardState.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation

/// Operational state of the Inactivity Guard subsystem.
public enum InactivityGuardState: Equatable, Sendable {
    /// Guard is turned off by the user (opt-in default).
    case disabled
    /// Actively monitoring accelerometer motion & screen interaction.
    case monitoring(stillSince: Date)
    /// In the 30-second pre-alarm silent warning countdown before auto-SOS dispatch.
    case warning(remainingSeconds: Double)
    /// Warning countdown completed; automatic SOS has been dispatched.
    case triggered
}


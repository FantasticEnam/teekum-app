//
//  LocationServiceError.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation

/// Explicit errors thrown during location lifecycle operations.
nonisolated public enum LocationServiceError: Error, LocalizedError, Equatable {
    case locationServicesDisabled
    case permissionDenied
    case permissionRestricted
    case trackingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            return "Location Services are disabled on this device in System Settings."
        case .permissionDenied:
            return "Location permission was denied. Please allow location access in Settings."
        case .permissionRestricted:
            return "Location access is restricted (e.g. Parental Controls)."
        case let .trackingFailed(reason):
            return "Location tracking failed: \(reason)"
        }
    }
}

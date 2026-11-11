//
//  LocationServiceDelegate.swift
//  Teekum
//
//  Created by Nicho on 10/11/26.
//

import Foundation
import CoreLocation

// MARK: - Core Location Delegate Callbacks

extension LocationService {
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            guard let self, self.isTracking else { return }
            for location in locations {
                self.applyLocationMeasurement(location)
            }
        }
    }
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor [weak self] in
            guard let self, self.isTracking else { return }
            self.currentHeading = heading
            self.onHeadingUpdate?(heading)
        }
    }
    
    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.authorizationStatus = newStatus
            
            switch newStatus {
            #if os(iOS)
            case .authorizedWhenInUse, .authorizedAlways:
                self.isGPSAvailable = true
                self.permissionContinuation?.resume(returning: true)
                self.permissionContinuation = nil
                if self.isTracking {
                    self.locationManager.startUpdatingLocation()
                    if CLLocationManager.headingAvailable() {
                        self.locationManager.startUpdatingHeading()
                    }
                }
            #else
            case .authorizedAlways:
                self.isGPSAvailable = true
                self.permissionContinuation?.resume(returning: true)
                self.permissionContinuation = nil
                if self.isTracking {
                    self.locationManager.startUpdatingLocation()
                }
            #endif
            case .denied, .restricted:
                self.isGPSAvailable = false
                self.permissionContinuation?.resume(returning: false)
                self.permissionContinuation = nil
            case .notDetermined:
                break
            @unknown default:
                self.isGPSAvailable = false
                self.permissionContinuation?.resume(returning: false)
                self.permissionContinuation = nil
            }
        }
    }
    
    public nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            if let clError = error as? CLError {
                if clError.code == .denied {
                    self.isGPSAvailable = false
                }
            }
        }
    }
}

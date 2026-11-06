//
//  MapPointViewModel.swift
//  
//
//  Created by Adiat Rahman on 05/11/26.
//

import Foundation
import SwiftUI
import CoreLocation
import Observation
import MapKit

@Observable
@MainActor
public final class MapPointViewModel {
    // State Peta
    public var cameraPosition: MapCameraPosition = .automatic
    
    // State Map Point
    private var activeMapPoint: MapPoint? = nil
    public var candidateCoordinate: CLLocationCoordinate2D? = nil
    public var isShowingConfirmation: Bool = false
    
    public var currentUserId: String = "ME" // Injectable
    
    public var hasActiveMapPoint: Bool {
        activeMapPoint != nil
    }
    
    public var isCurrentUserProposer: Bool {
        guard let active = activeMapPoint else { return false }
        return active.proposerId == currentUserId
    }
    
        
}

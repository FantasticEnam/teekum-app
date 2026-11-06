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
    public var activeMapPoint: MapPoint? = nil
    public var candidateCoordinate: CLLocationCoordinate2D? = nil
    
    // State Native Alert
    public var isShowingSetAlert: Bool = false
    public var isShowingStopAlert: Bool = false
    public var isShowingLockedAlert: Bool = false
    public var isShowingRSVPAlert: Bool = false
    
    public var currentUserId: String = "MEE" // Injectable
    
    public var myAttendance: AttendanceStatus? = nil
    
    public var hasActiveMapPoint: Bool {
        activeMapPoint != nil
    }
    
    public var isCurrentUserProposer: Bool {
        guard let active = activeMapPoint else { return false }
        return active.proposerId == currentUserId
    }
    
    
    public var isLockedByOther: Bool {
        hasActiveMapPoint && !isCurrentUserProposer
    }
    
    // 1. Saat hold di map
    public func handleMapHold(at coordinate: CLLocationCoordinate2D) {
        // Jika udah ada meeting point aktif
        if hasActiveMapPoint {
            self.isShowingLockedAlert = true
            return
        }
        
        // Simpan titik sementara & alert konfirmasi
        self.candidateCoordinate = coordinate
        self.isShowingSetAlert = true
    }
    
    // 2. konfirmasi
    public func confirmSetMeetingPoint(){
        guard let coord = candidateCoordinate else { return }
        
        self.activeMapPoint = MapPoint(coordinate: coord, proposerId: currentUserId, title: "\(currentUserId)'s Meeting Point")
        
        // Reset titik kandidat
        self.candidateCoordinate = nil
        self.isShowingSetAlert = false
    }
    
    // 3. saat batal di konfirmasi
    public func cancelSetMeetingPoint() {
        self.candidateCoordinate = nil
        self.isShowingSetAlert = false
    }
    
    // 4. saat titik pin meeting poin di tap di map
    public func handlePinTapped() {
        guard hasActiveMapPoint else { return }
        
        if isCurrentUserProposer {
            self.isShowingStopAlert = true
        } else {
            self.isShowingRSVPAlert = true
        }
    }
    
    // 5. saat stop meeting point
    public func stopMeetingPoint(){
        guard isCurrentUserProposer else { return }
        self.activeMapPoint = nil
        self.candidateCoordinate = nil
        self.isShowingStopAlert = false
    }
    
    public func respondRSVP(attending: Bool){
        let status: AttendanceStatus = attending ? .attending : .cantMakeIt
        self.myAttendance = status
        
        // Current User attendance
        if var point = activeMapPoint {
            point.attendance[currentUserId] = status
            self.activeMapPoint = point
        }
        self.isShowingRSVPAlert = false
        print("User \(currentUserId) RSVP: \(status.title)")
    }
    
    public func simulateOtherUserMeetingPoint(){
        self.activeMapPoint = MapPoint(coordinate: CLLocationCoordinate2D(latitude: -6.2186, longitude: 106.8026),
                                       proposerId: "NIC",
                                       title: "NIC's Meeting Point")
    }
        
}

//
//  MapPointViewModel.swift
//  
//
//  Created by Adiat Rahman on 05/11/26.
//

import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
public final class MapPointViewModel {
    private let sessionStore: SessionStore
    @ObservationIgnored private var locationManager: CLLocationManager?

    public var activeMapPoint: MeetingPoint? { sessionStore.activeMeetingPoint }
    public private(set) var candidateCoordinate: CLLocationCoordinate2D?
    
    // State Native Alert
    public var isShowingSetAlert: Bool = false
    public var isShowingStopAlert: Bool = false
    public var isShowingLockedAlert: Bool = false
    public var isShowingRSVPAlert: Bool = false
    
    public init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore
    }

    public var myAttendance: MeetingAttendance? {
        guard let memberID = sessionStore.activeSession?.localMemberId else { return nil }
        return activeMapPoint?.attendance[memberID]
    }
    
    public var hasActiveMapPoint: Bool {
        activeMapPoint != nil
    }
    
    public var isCurrentUserProposer: Bool {
        guard let active = activeMapPoint,
              let memberID = sessionStore.activeSession?.localMemberId else { return false }
        return active.proposerId == memberID
    }
    
    
    public var isLockedByOther: Bool {
        hasActiveMapPoint && !isCurrentUserProposer
    }

    public func requestLocationPermission() {
        if locationManager == nil { locationManager = CLLocationManager() }
        if locationManager?.authorizationStatus == .notDetermined {
            locationManager?.requestWhenInUseAuthorization()
        }
    }
    
    // 1. Saat hold di map
    public func handleMapHold(at coordinate: CLLocationCoordinate2D) {
        guard sessionStore.hasActiveSession,
              CLLocationCoordinate2DIsValid(coordinate) else { return }
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
    public func confirmSetMeetingPoint() {
        defer { cancelSetMeetingPoint() }
        guard let session = sessionStore.activeSession,
              let coord = candidateCoordinate else { return }
        guard !hasActiveMapPoint else {
            isShowingLockedAlert = true
            return
        }

        sessionStore.activeMeetingPoint = MeetingPoint(
            name: "\(session.localInitials)'s Meeting Point",
            coordinate: coord,
            proposerId: session.localMemberId,
            proposerInitials: session.localInitials
        )
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
        sessionStore.activeMeetingPoint = nil
        self.candidateCoordinate = nil
        self.isShowingStopAlert = false
    }
    
    public func respondRSVP(attending: Bool){
        guard let memberID = sessionStore.activeSession?.localMemberId,
              var point = activeMapPoint else { return }
        let status: MeetingAttendance = attending ? .accepted : .declined
        point.attendance[memberID] = status
        sessionStore.activeMeetingPoint = point
        self.isShowingRSVPAlert = false
    }
}

public enum MapPointAlert: Identifiable {
    case setConfirmation
    case stopConfirmation
    case rsvp
    case locked
    
    public var id: Self { self }
}

//
//  MeetingPointViewModel.swift
//  
//
//  Created by Adiat Rahman on 05/11/26.
//

import Foundation
import CoreLocation
import Observation

@Observable
@MainActor
public final class MeetingPointViewModel {
    private let sessionStore: SessionStore
    private let meetingService: MeetingPointService
    @ObservationIgnored private var locationManager: CLLocationManager?

    public var activeMapPoint: MeetingPoint? { sessionStore.activeMeetingPoint }
    public private(set) var candidateCoordinate: CLLocationCoordinate2D?
    
    // State Native Alert
    public var isShowingSetAlert: Bool = false
    public var isShowingStopAlert: Bool = false
    public var isShowingLockedAlert: Bool = false //
    public var isShowingRSVPAlert: Bool = false
    public var isShowingTimeOptions = false
    public var timePreset: MeetingTimePreset = .rightNow
    public var isCustomTime = false
    public var customTime = Date.now
    
    public init(sessionStore: SessionStore, meetingService: MeetingPointService? = nil) {
        self.sessionStore = sessionStore
        self.meetingService = meetingService ?? MeetingPointService(sessionStore: sessionStore)
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
        meetingService.checkExpiration()
        
        // Simpan titik sementara & alert konfirmasi
        self.candidateCoordinate = coordinate
        self.isShowingSetAlert = true
    }
    
    // 2. konfirmasi
    public func confirmSetMeetingPoint() {
        defer { cancelSetMeetingPoint() }
        guard sessionStore.hasActiveSession,
              let coord = candidateCoordinate else { return }

        meetingService.proposeMeetingPoint(coordinate: coord,
            meetupTime: isCustomTime ? customTime : timePreset.targetDate(),
            isRightNow: !isCustomTime && timePreset == .rightNow)
    }
    
    // 3. saat batal di konfirmasi
    public func cancelSetMeetingPoint() {
        self.candidateCoordinate = nil
        self.isShowingSetAlert = false
        self.isShowingTimeOptions = false
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
        guard meetingService.cancelMeetingPoint() else { return }
        self.candidateCoordinate = nil
        self.isShowingStopAlert = false
    }
    
    public func respondRSVP(attending: Bool){
        meetingService.respond(status: attending ? .attending : .cantMakeIt)
        self.isShowingRSVPAlert = false
    }

    public var errorMessage: String? { meetingService.errorMessage }
}



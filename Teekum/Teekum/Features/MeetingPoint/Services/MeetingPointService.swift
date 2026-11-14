//
//  MeetingPointService.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CoreLocation
import CryptoKit
import Foundation
import Observation

/// Meeting rules and wire dispatch; the shared store remains the only owner of the active point.
@MainActor
@Observable
public final class MeetingPointService {
    private let sessionStore: SessionStore
    private let cryptoService: (any CryptoServiceProtocol)?
    private let transport: (any PeerTransport)?
    private let sequenceAllocator: PacketSequenceAllocator?
    private var monotonicCounter: UInt32 = 1
    private var pendingSends: [UUID: Task<Void, Never>] = [:]
    private var generation = UUID()
    public private(set) var errorMessage: String?

    public init(
        sessionStore: SessionStore,
        cryptoService: (any CryptoServiceProtocol)? = nil,
        transport: (any PeerTransport)? = nil,
        sequenceAllocator: PacketSequenceAllocator? = nil
    ) {
        self.sessionStore = sessionStore
        self.cryptoService = cryptoService
        self.transport = transport
        self.sequenceAllocator = sequenceAllocator
    }

    public func canSetMeetingPoint(by initials: String) -> Bool {
        checkExpiration()
        return sessionStore.hasActiveSession
    }

    @discardableResult
    public func proposeMeetingPoint(
        coordinate: CLLocationCoordinate2D,
        meetupTime: Date = .now,
        isRightNow: Bool = true,
        anchorToProposerGPS: Bool = false,
        arrivalRadiusMeters: Double = 25
    ) -> Bool {
        guard let session = sessionStore.activeSession,
              CLLocationCoordinate2DIsValid(coordinate) else { return false }
        let point = MeetingPoint(
            name: "\(session.localInitials)'s Meeting Point",
            coordinate: coordinate,
            targetTime: meetupTime,
            proposerId: session.localMemberId,
            proposerInitials: session.localInitials,
            attendance: [session.localMemberId: .accepted],
            isRightNow: isRightNow,
            anchorToProposerGPS: anchorToProposerGPS,
            arrivalRadiusMeters: arrivalRadiusMeters
        )
        sessionStore.activeMeetingPoint = point
        send(action: .propose, point: point, attendance: .attending)
        return true
    }

    public func respond(status: AttendanceStatus) {
        checkExpiration()
        guard let session = sessionStore.activeSession,
              var point = sessionStore.activeMeetingPoint else { return }
        point.attendance[session.localMemberId] = MeetingAttendance(rawValue: status.rawValue)
        sessionStore.activeMeetingPoint = point
        send(action: status == .cantMakeIt ? .decline : .accept, point: point, attendance: status)
    }

    @discardableResult
    public func cancelMeetingPoint() -> Bool {
        guard let session = sessionStore.activeSession,
              let point = sessionStore.activeMeetingPoint,
              point.proposerId == session.localMemberId else { return false }
        sessionStore.activeMeetingPoint = nil
        let attendance = point.attendance[session.localMemberId]
            .flatMap { AttendanceStatus(rawValue: $0.rawValue) } ?? .attending
        send(action: .cancel, point: point, attendance: attendance)
        return true
    }

    public func checkArrival(userLocation: CLLocationCoordinate2D) {
        checkExpiration()
        guard let session = sessionStore.activeSession,
              let point = sessionStore.activeMeetingPoint,
              point.attendance[session.localMemberId] != .arrived,
              CLLocationCoordinate2DIsValid(userLocation) else { return }
        let user = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let destination = CLLocation(latitude: point.latitude, longitude: point.longitude)
        if user.distance(from: destination) <= point.arrivalRadiusMeters {
            respond(status: .atMeetingPoint)
        }
    }

    public func checkExpiration() {
        if sessionStore.activeMeetingPoint?.isExpired == true {
            sessionStore.activeMeetingPoint = nil
        }
    }

    @discardableResult
    public func applyInboundUpdate(_ update: MeetingUpdatePayload) -> Bool {
        guard sessionStore.activeSession != nil else { return false }
        switch update.action {
        case .propose:
            checkExpiration()
            if let existing = sessionStore.activeMeetingPoint, existing.id == update.meetingPointId {
                return false
            }
            let point = MeetingPoint(
                id: update.meetingPointId,
                name: "\(update.senderInitials)'s Meeting Point",
                coordinate: update.coordinate,
                targetTime: update.meetupTime,
                proposerId: .fromInitials(update.senderInitials),
                proposerInitials: update.senderInitials,
                attendance: [.fromInitials(update.senderInitials): MeetingAttendance(rawValue: update.attendanceStatus.rawValue) ?? .accepted],
                createdAt: update.createdAt,
                isRightNow: update.isRightNow,
                anchorToProposerGPS: update.anchorToProposerGPS,
                arrivalRadiusMeters: Double(update.arrivalRadiusMeters)
            )
            guard !point.isExpired else { return false }
            sessionStore.activeMeetingPoint = point
            return true
        case .cancel:
            guard let point = sessionStore.activeMeetingPoint,
                  point.id == update.meetingPointId,
                  point.proposerInitials == update.senderInitials else { return false }
            sessionStore.activeMeetingPoint = nil
            return true
        case .accept, .decline:
            guard var point = sessionStore.activeMeetingPoint,
                  point.id == update.meetingPointId,
                  let status = MeetingAttendance(rawValue: update.attendanceStatus.rawValue) else { return false }
            let memberId = MemberID.fromInitials(update.senderInitials)
            guard point.attendance[memberId] != status else { return false }
            point.attendance[memberId] = status
            sessionStore.activeMeetingPoint = point
            return true
        }
    }

    public func syncActiveMeetingPointToPeers() async {
        checkExpiration()
        guard let session = sessionStore.activeSession,
              let point = sessionStore.activeMeetingPoint else { return }
        let proposerAttendance = point.attendance[point.proposerId]
            .flatMap { AttendanceStatus(rawValue: $0.rawValue) } ?? .attending
        await broadcastMeetingUpdate(
            action: .propose,
            point: point,
            attendance: proposerAttendance,
            senderInitials: point.proposerInitials
        )
        if point.proposerId != session.localMemberId,
           let localAttendance = point.attendance[session.localMemberId],
           let wireAttendance = AttendanceStatus(rawValue: localAttendance.rawValue) {
            await broadcastMeetingUpdate(
                action: localAttendance == .declined ? .decline : .accept,
                point: point,
                attendance: wireAttendance,
                senderInitials: session.localInitials
            )
        }
    }

    public func reset() {
        generation = UUID()
        for task in pendingSends.values { task.cancel() }
        pendingSends.removeAll()
        sessionStore.activeMeetingPoint = nil
        errorMessage = nil
    }

    private func send(action: MeetingAction, point: MeetingPoint, attendance: AttendanceStatus) {
        let id = UUID()
        pendingSends[id] = Task { [weak self] in
            guard let self else { return }
            await broadcastMeetingUpdate(action: action, point: point, attendance: attendance)
            pendingSends.removeValue(forKey: id)
        }
    }

    private func broadcastMeetingUpdate(
        action: MeetingAction,
        point: MeetingPoint,
        attendance: AttendanceStatus,
        senderInitials: String? = nil
    ) async {
        guard !Task.isCancelled,
              let session = sessionStore.activeSession,
              let cryptoService, let transport else { return }
        let currentGeneration = generation
        let payload = MeetingUpdatePayload(
            coordinate: point.coordinate,
            meetupTime: point.meetupTime,
            createdAt: point.createdAt,
            action: action,
            attendanceStatus: attendance,
            meetingPointId: point.id,
            senderInitials: senderInitials ?? session.localInitials,
            arrivalRadiusMeters: UInt8(min(100, max(5, point.arrivalRadiusMeters.rounded()))),
            isRightNow: point.isRightNow,
            anchorToProposerGPS: point.anchorToProposerGPS
        )
        do {
            let sequence: UInt32
            if let sequenceAllocator {
                sequence = try await sequenceAllocator.next(for: session)
            } else {
                sequence = CleartextEnvelope.makeSequenceNumber(memberSlot: session.memberSlot, counter: monotonicCounter)
                monotonicCounter &+= 1
            }
            guard !Task.isCancelled, generation == currentGeneration,
                  sessionStore.activeSession == session else { return }
            let envelope = CleartextEnvelope(
                type: .meetingUpdate,
                hopLimit: PacketConstants.meetingPointHopLimit,
                sessionId: session.sessionId,
                sequenceNumber: sequence
            )
            let data = try await cryptoService.sealToWireBytes(
                payload: payload.serialize(), envelope: envelope,
                using: SymmetricKey(data: session.symmetricKeyData)
            )
            guard !Task.isCancelled, generation == currentGeneration,
                  sessionStore.activeSession == session else { return }
            try await transport.broadcastPacket(data)
            guard generation == currentGeneration else { return }
            errorMessage = nil
        } catch {
            guard generation == currentGeneration, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }
}

//
//  PairingMeetingMigrationTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import CoreLocation
import XCTest
@testable import Teekum

@MainActor
final class PairingMeetingMigrationTests: XCTestCase {
    func testInviteFingerprintUsesSameKeyDigestForHostAndJoiner() throws {
        let key = Data((0..<32).map(UInt8.init))
        let host = GroupSession(symmetricKeyData: key, localInitials: "ADI")
        let invite = try XCTUnwrap(GroupSession.parseInvite(from: host.inviteURL()))
        let joiner = try GroupSessionFactory.join(invite: invite, initials: "NIC", colorCode: 2)

        XCTAssertEqual(host.keyFingerprint, "0x630DCD29")
        XCTAssertEqual(joiner.keyFingerprint, host.keyFingerprint)
    }

    func testPrivateGroupInvitePreservesPrototypeSessionContract() throws {
        let host = try GroupSessionFactory.create(name: "Festival Crew", initials: "ADI", colorCode: 7)
        let invite = try XCTUnwrap(GroupSession.parseInvite(from: host.inviteURL()))
        let friend = try GroupSessionFactory.join(invite: invite, initials: "NIC", colorCode: 2)
        XCTAssertNotEqual(host.sessionId, 0)
        XCTAssertEqual(host.symmetricKeyData.count, 32)
        XCTAssertEqual(friend.sessionId, host.sessionId)
        XCTAssertEqual(friend.sessionName, host.sessionName)
        XCTAssertEqual(friend.symmetricKeyData, host.symmetricKeyData)
        XCTAssertEqual(friend.localInitials, "NIC")
        XCTAssertEqual(friend.localColorCode, 2)
        XCTAssertFalse(friend.isHost)
    }

    func testPairingDoesNotActivateBeforeAgreementAction() throws {
        let store = SessionStore()
        var accepted: GroupSession?
        let viewModel = PairingViewModel(sessionStore: store) { accepted = $0 }
        viewModel.form = PairingForm(initials: "ADI", sessionName: "Festival Crew", profileColor: .blue)
        viewModel.showQRPreview()
        XCTAssertNotNil(viewModel.draftSession)
        XCTAssertNil(store.activeSession)
        XCTAssertNil(accepted)
        viewModel.activateLocalSession()
        XCTAssertEqual(accepted?.sessionId, viewModel.draftSession?.sessionId)
        XCTAssertEqual(accepted?.localColorCode, 7)
    }

    func testInvalidInviteAndInitialsCannotCreateParticipation() {
        for initials in ["", "ABCD", "A1", "🦉"] {
            XCTAssertThrowsError(try GroupSessionFactory.create(name: "Crew", initials: initials, colorCode: 1))
        }
        let invite = GroupSessionInvite(sessionId: 0x1234, sessionName: "Crew", keyData: Data(repeating: 1, count: 31))
        XCTAssertThrowsError(try GroupSessionFactory.join(invite: invite, initials: "ADI", colorCode: 1))
        let viewModel = PairingViewModel(sessionStore: SessionStore())
        viewModel.form.initials = "ADI"
        viewModel.mode = .join
        viewModel.handleScannedCode("not a TeeKum invite")
        XCTAssertNil(viewModel.scannedInvite)
        XCTAssertFalse(viewModel.canPerformPrimaryAction)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testMeetingSetterLockAndAttendanceMatchPrototypeRules() throws {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ADI"))
        let service = MeetingPointService(sessionStore: store)
        let coordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        XCTAssertTrue(service.proposeMeetingPoint(coordinate: coordinate))
        let point = try XCTUnwrap(store.activeMeetingPoint)
        XCTAssertTrue(service.canSetMeetingPoint(by: "ADI"))
        XCTAssertTrue(service.canSetMeetingPoint(by: "NIC"))
        XCTAssertFalse(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .cancel, attendanceStatus: .attending,
            meetingPointId: point.id, senderInitials: "NIC"
        )))
        XCTAssertTrue(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .accept, attendanceStatus: .atMeetingPoint,
            meetingPointId: point.id, senderInitials: "NIC"
        )))
        XCTAssertEqual(store.activeMeetingPoint?.attendance[.fromInitials("NIC")], .arrived)
        XCTAssertTrue(service.cancelMeetingPoint())
        XCTAssertNil(store.activeMeetingPoint)
    }
    
    func testNewMeetingPointReplacesExistingPoint() throws {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ADI"))
        let service = MeetingPointService(sessionStore: store)
        let coordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        XCTAssertTrue(service.proposeMeetingPoint(coordinate: coordinate))
        let firstPoint = try XCTUnwrap(store.activeMeetingPoint)

        XCTAssertTrue(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .propose, attendanceStatus: .attending,
            meetingPointId: firstPoint.id + 1, senderInitials: "NIC"
        )))
        XCTAssertEqual(store.activeMeetingPoint?.id, firstPoint.id + 1)
        XCTAssertEqual(store.activeMeetingPoint?.proposerInitials, "NIC")
    }

    func testMeetingArrivalAndOneHourExpiryMatchPrototype() throws {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ADI"))
        let service = MeetingPointService(sessionStore: store)
        let coordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        XCTAssertTrue(service.proposeMeetingPoint(coordinate: coordinate))
        service.checkArrival(userLocation: coordinate)
        XCTAssertEqual(store.activeMeetingPoint?.attendance[.fromInitials("ADI")], .arrived)
        store.activeMeetingPoint = MeetingPoint(
            name: "Expired", coordinate: coordinate,
            targetTime: .now.addingTimeInterval(-3601), proposerInitials: "ADI"
        )
        service.checkExpiration()
        XCTAssertNil(store.activeMeetingPoint)
    }
}

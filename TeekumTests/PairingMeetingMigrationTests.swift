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
        XCTAssertTrue(PacketConstants.isValidSessionId(host.sessionId))
        XCTAssertEqual(host.symmetricKeyData.count, 32)
        XCTAssertEqual(friend.sessionId, host.sessionId)
        XCTAssertEqual(friend.sessionName, host.sessionName)
        XCTAssertEqual(friend.symmetricKeyData, host.symmetricKeyData)
        XCTAssertEqual(friend.localInitials, "NIC")
        XCTAssertEqual(friend.localColorCode, 2)
        XCTAssertFalse(friend.isHost)

        let sid24Host = GroupSession(sessionId: 0xAB1234, sessionName: "TwentyFour", symmetricKeyData: host.symmetricKeyData, localInitials: "ADI")
        let sid24URL = sid24Host.inviteURL()
        XCTAssertTrue(sid24URL.absoluteString.contains("sid=AB1234"))
        let sid24Invite = try XCTUnwrap(GroupSession.parseInvite(from: sid24URL))
        XCTAssertEqual(sid24Invite.sessionId, 0xAB1234)
        let sid24Friend = try GroupSessionFactory.join(invite: sid24Invite, initials: "NIC", colorCode: 2)
        XCTAssertEqual(sid24Friend.sessionId, 0xAB1234)
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
        let validKey = Data(repeating: 1, count: 32)
        XCTAssertThrowsError(try GroupSessionFactory.join(invite: .init(sessionId: 0, sessionName: "Crew", keyData: validKey), initials: "ADI", colorCode: 1))
        XCTAssertThrowsError(try GroupSessionFactory.join(invite: .init(sessionId: 0x0100_0000, sessionName: "Crew", keyData: validKey), initials: "ADI", colorCode: 1))
        let encodedKey = validKey.base64EncodedString()
        XCTAssertNil(GroupSession.parseInvite(from: "meepo://join#key=\(encodedKey)&sid=000000&name=Crew"))
        XCTAssertNil(GroupSession.parseInvite(from: "meepo://join#key=\(encodedKey)&sid=01000000&name=Crew"))
        let viewModel = PairingViewModel(sessionStore: SessionStore())
        viewModel.form.initials = "ADI"
        viewModel.mode = .join
        viewModel.handleScannedCode("not a TeeKum invite")
        XCTAssertNil(viewModel.scannedInvite)
        XCTAssertFalse(viewModel.canPerformPrimaryAction)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testPasteInviteMatchesShareLinkMessageAndRejectsEmptyClipboard() throws {
        let host = try GroupSessionFactory.create(name: "Festival Crew", initials: "ADI", colorCode: 7)
        let inviteURL = host.inviteURL().absoluteString
        let sharedMessage = "Join my group on Meepo: \(host.sessionName)\n\(inviteURL)."

        let viewModel = PairingViewModel(sessionStore: SessionStore())
        viewModel.form.initials = "NIC"
        viewModel.mode = .join

        viewModel.pasteInvite(candidates: [])
        XCTAssertNil(viewModel.scannedInvite)
        XCTAssertEqual(viewModel.errorMessage, PairingError.emptyClipboard.localizedDescription)

        viewModel.pasteInvite(candidates: [sharedMessage])
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.scannedInvite?.sessionId, host.sessionId)
        XCTAssertEqual(viewModel.scannedInvite?.sessionName, host.sessionName)
        XCTAssertEqual(viewModel.scannedInvite?.keyData, host.symmetricKeyData)
        XCTAssertTrue(viewModel.canPerformPrimaryAction)

        // Multi-item pasteboard fallback: message text without URL + separate URL item.
        let fallbackModel = PairingViewModel(sessionStore: SessionStore())
        fallbackModel.form.initials = "NIC"
        fallbackModel.pasteInvite(candidates: ["Join my group on Meepo: \(host.sessionName)", inviteURL])
        XCTAssertNil(fallbackModel.errorMessage)
        XCTAssertEqual(fallbackModel.scannedInvite?.sessionId, host.sessionId)
    }

    func testMeetingSetterLockAndAttendanceMatchPrototypeRules() throws {
        let store = SessionStore(activeSession: GroupSession(localInitials: "ADI"))
        let service = MeetingPointService(sessionStore: store)
        let coordinate = CLLocationCoordinate2D(latitude: -6.2, longitude: 106.8)
        XCTAssertTrue(service.proposeMeetingPoint(coordinate: coordinate))
        let point = try XCTUnwrap(store.activeMeetingPoint)
        XCTAssertTrue(service.canSetMeetingPoint(by: "ADI"))
        XCTAssertFalse(service.canSetMeetingPoint(by: "NIC"))
        XCTAssertFalse(service.applyInboundUpdate(MeetingUpdatePayload(
            coordinate: coordinate, action: .propose, attendanceStatus: .attending,
            meetingPointId: point.id + 1, senderInitials: "NIC"
        )))
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

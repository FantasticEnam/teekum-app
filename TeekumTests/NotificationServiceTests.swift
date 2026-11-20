//
//  NotificationServiceTests.swift
//  TeekumTests
//
//  Created by Antigravity on 19/11/26.
//

import XCTest
import UserNotifications
import CryptoKit
@testable import Teekum

final class NotificationServiceTests: XCTestCase {

    @MainActor
    func testBannerPresentationAndDismissal() {
        let notifications = NotificationService()
        let url = URL(string: "teekum://meeting")
        notifications.notify(
            title: "Meeting Point Set!",
            body: "ADI set up a new meeting point!",
            icon: "mappin.and.ellipse",
            interruptionLevel: .active,
            deepLinkURL: url
        )

        XCTAssertNotNil(notifications.banner)
        XCTAssertEqual(notifications.banner?.title, "Meeting Point Set!")
        XCTAssertEqual(notifications.banner?.body, "ADI set up a new meeting point!")
        XCTAssertEqual(notifications.banner?.icon, "mappin.and.ellipse")
        XCTAssertEqual(notifications.banner?.deepLinkURL, url)

        notifications.dismissBanner()
        XCTAssertNil(notifications.banner)
    }

    @MainActor
    func testHelperOnTheWayBannerAndDeepLink() {
        let notifications = NotificationService()
        let deepLink = URL(string: "teekum://sos?member=NIC")

        notifications.notify(
            title: "Helper on the way!",
            body: "NIC is heading to help you!",
            icon: "figure.walk.motion",
            interruptionLevel: .timeSensitive,
            deepLinkURL: deepLink
        )

        XCTAssertEqual(notifications.banner?.title, "Helper on the way!")
        XCTAssertEqual(notifications.banner?.body, "NIC is heading to help you!")
        XCTAssertEqual(notifications.banner?.icon, "figure.walk.motion")
        XCTAssertEqual(notifications.banner?.deepLinkURL, deepLink)
    }

    @MainActor
    func testSOSResolvedBannerAndDeepLink() {
        let notifications = NotificationService()
        let deepLink = URL(string: "teekum://orbit")

        notifications.notify(
            title: "SOS Resolved",
            body: "NIC has resolved their emergency alert.",
            icon: "checkmark.circle.fill",
            interruptionLevel: .timeSensitive,
            deepLinkURL: deepLink
        )

        XCTAssertEqual(notifications.banner?.title, "SOS Resolved")
        XCTAssertEqual(notifications.banner?.body, "NIC has resolved their emergency alert.")
        XCTAssertEqual(notifications.banner?.icon, "checkmark.circle.fill")
        XCTAssertEqual(notifications.banner?.deepLinkURL, deepLink)
    }

    @MainActor
    func testFollowIntentBannerAndDeepLink() {
        let notifications = NotificationService()
        let deepLink = URL(string: "teekum://follow?initials=ADI")

        notifications.notify(
            title: "ADI followed you",
            body: "Stay where you are so they can find you.",
            icon: "person.2.fill",
            interruptionLevel: .active,
            deepLinkURL: deepLink
        )

        XCTAssertEqual(notifications.banner?.title, "ADI followed you")
        XCTAssertEqual(notifications.banner?.body, "Stay where you are so they can find you.")
        XCTAssertEqual(notifications.banner?.icon, "person.2.fill")
        XCTAssertEqual(notifications.banner?.deepLinkURL, deepLink)
    }

    @MainActor
    func testNotificationServiceOnOpenURLCallback() {
        let notifications = NotificationService()
        var openedURL: URL?
        notifications.onOpenURL = { url in
            openedURL = url
        }
        let testURL = URL(string: "teekum://meeting")!
        notifications.onOpenURL?(testURL)
        XCTAssertEqual(openedURL, testURL)
    }

    @MainActor
    func testSessionControllerDeepLinkRouting() {
        let store = SessionStore()
        store.activeSession = GroupSession(sessionId: 0x1234, localInitials: "MEE")
        let controller = SessionController(store: store)

        // Verify meeting route
        let meetingURL = URL(string: "teekum://meeting")!
        controller.handleURL(meetingURL)
        XCTAssertEqual(store.pendingDeepLink, meetingURL)

        // Verify SOS route
        let sosURL = URL(string: "teekum://sos?member=NIC")!
        controller.handleURL(sosURL)
        XCTAssertEqual(store.pendingDeepLink, sosURL)

        // Verify follow route
        let followURL = URL(string: "teekum://follow?initials=ADI")!
        controller.handleURL(followURL)
        XCTAssertEqual(store.pendingDeepLink, followURL)

        // Verify orbit route
        let orbitURL = URL(string: "teekum://orbit")!
        controller.handleURL(orbitURL)
        XCTAssertEqual(store.pendingDeepLink, orbitURL)

        // Verify chat route
        let chatURL = URL(string: "teekum://chat")!
        controller.handleURL(chatURL)
        XCTAssertEqual(store.pendingDeepLink, chatURL)
    }
}

//
//  ChatNotificationTests.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 17/11/26.
//

import XCTest
@testable import Teekum

final class ChatNotificationTests: XCTestCase {
    @MainActor
    func testSwipeDismissalRequiresAnUpwardDrag() {
        XCTAssertFalse(ChatNotificationBannerView.dismissesSwipe(.zero))
        XCTAssertFalse(ChatNotificationBannerView.dismissesSwipe(.init(width: 0, height: -29)))
        XCTAssertFalse(ChatNotificationBannerView.dismissesSwipe(.init(width: 0, height: 40)))
        XCTAssertFalse(ChatNotificationBannerView.dismissesSwipe(.init(width: 60, height: -40)))
        XCTAssertTrue(ChatNotificationBannerView.dismissesSwipe(.init(width: 5, height: -30)))
    }

    @MainActor
    func testDismissingTheLatestBannerAllowsAnotherMessageToAppear() {
        let notifications = NotificationService()
        notifications.notifyChat(sender: "NIC", body: "I'm safe")
        notifications.notifyChat(sender: "ADI", body: "I've arrived")
        XCTAssertEqual(notifications.chatAlert?.sender, "ADI")

        notifications.dismissChatAlert()
        XCTAssertNil(notifications.chatAlert)

        notifications.notifyChat(sender: "NIC", body: "At the shelter")
        XCTAssertEqual(notifications.chatAlert?.sender, "NIC")
        XCTAssertEqual(notifications.chatAlert?.body, "At the shelter")
    }

    @MainActor
    func testMessagesDoNotShowBannersWhileChatIsOpen() {
        let notifications = NotificationService()
        notifications.notifyChat(sender: "NIC", body: "I'm safe")

        for index in 0..<20 {
            notifications.notifyChat(sender: "ADI", body: "Message \(index)", showBanner: false)
            XCTAssertNil(notifications.chatAlert)
        }

        notifications.notifyChat(sender: "NIC", body: "On my way")
        XCTAssertEqual(notifications.chatAlert?.body, "On my way")
    }

    @MainActor
    func testChatDismissalPreservesGroupActivity() {
        let notifications = NotificationService()
        notifications.notifyGroupActivity(["NIC"], joined: true)
        notifications.dismissChatAlert()
        notifications.notifyChat(sender: "ADI", body: "I'm safe", showBanner: false)

        XCTAssertEqual(notifications.groupActivity?.memberID, "NIC")
        XCTAssertNil(notifications.chatAlert)
    }
}

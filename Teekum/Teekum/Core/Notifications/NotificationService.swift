//
//  NotificationService.swift
//  Teekum
//
//  Created by DIMAS DAFFA ERNANDA on 11/11/26.
//

import Foundation
import Observation
import UserNotifications
import UIKit

@MainActor
@Observable
final class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    var message: String?
    private(set) var groupActivity: (message: String, memberID: String)?
    private var dismissTask: Task<Void, Never>?

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    func notify(title: String, body: String, showBanner: Bool = true) {
        if showBanner {
            showMessage("\(title): \(body)")
        }
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func notifyGroupActivity(_ members: [String], joined: Bool) {
        guard let first = members.first else { return }
        let names = members.formatted(.list(type: .and))
        let body = joined
            ? (members.count == 1 ? "\(names) has joined" : "\(names) have joined")
            : "Lost contact with \(names)"
        showMessage(body, memberID: first)
        notify(title: "Group activity", body: body, showBanner: false)
    }

    private func showMessage(_ text: String, memberID: String? = nil) {
        message = memberID == nil ? text : nil
        groupActivity = memberID.map { (text, $0) }
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(4)) } catch { return }
            self?.message = nil
            self?.groupActivity = nil
        }
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        message = nil
        groupActivity = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

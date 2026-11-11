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
            message = "\(title): \(body)"
            dismissTask?.cancel()
            dismissTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(4)) } catch { return }
                self?.message = nil
            }
        }
        guard UIApplication.shared.applicationState != .active else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func clear() {
        dismissTask?.cancel()
        dismissTask = nil
        message = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}

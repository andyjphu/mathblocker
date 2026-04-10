//
//  ShieldActionExtension.swift
//  shconf
//
//  Created by Andy Phu on 4/9/26.
//

import ManagedSettings
import Foundation
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {

    private let suiteName = "group.andyjphu.mathblocker"

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            signalUnlockRequest()
            sendOpenAppNotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.none)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction,
                         for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            signalUnlockRequest()
            sendOpenAppNotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.none)
        @unknown default:
            completionHandler(.none)
        }
    }

    override func handle(action: ShieldAction,
                         for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            signalUnlockRequest()
            sendOpenAppNotification()
            completionHandler(.close)
        case .secondaryButtonPressed:
            completionHandler(.none)
        @unknown default:
            completionHandler(.none)
        }
    }

    private func signalUnlockRequest() {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(Date().timeIntervalSince1970, forKey: "unlockRequestTimestamp")
    }

    /// Schedules an immediate notification. When the user taps it,
    /// iOS launches MathBlocker since extensions can't open the parent
    /// app directly.
    private func sendOpenAppNotification() {
        let content = UNMutableNotificationContent()
        content.title = "tap to unlock"
        content.body = "solve a few problems to earn screen time back"
        content.sound = .default
        content.userInfo = ["action": "openChallenge"]

        let request = UNNotificationRequest(
            identifier: "shield-tap-\(UUID().uuidString)",
            content: content,
            trigger: nil // immediate
        )
        UNUserNotificationCenter.current().add(request)
    }
}

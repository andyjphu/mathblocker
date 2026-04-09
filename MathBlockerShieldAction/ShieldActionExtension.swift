//
//  ShieldActionExtension.swift
//  MathBlockerShieldAction
//
//  Created by Andy Phu on 4/9/26.
//

import ManagedSettings
import Foundation

class ShieldActionExtension: ShieldActionDelegate {

    private let suiteName = "group.andyjphu.mathblocker"

    override func handle(action: ShieldAction,
                         for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            // Signal the main app to open for math challenge
            signalUnlockRequest()
            // Defer temporarily removes the shield so user can interact
            completionHandler(.defer)

        case .secondaryButtonPressed:
            // User chose to stay focused — keep shield up
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
            completionHandler(.defer)
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
            completionHandler(.defer)
        case .secondaryButtonPressed:
            completionHandler(.none)
        @unknown default:
            completionHandler(.none)
        }
    }

    private func signalUnlockRequest() {
        // Write a flag to App Group so the main app knows to show the challenge
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(Date().timeIntervalSince1970, forKey: "unlockRequestTimestamp")

        // Also try to open the main app via URL scheme
        // Note: extensions can't call UIApplication.shared.open directly,
        // but .defer will dismiss the shield and the system may return to the app
        // if it was recently in the foreground
    }
}

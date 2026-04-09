//
//  ShieldActionExtension.swift
//  shconf
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
            signalUnlockRequest()
            completionHandler(.defer)
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
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.set(Date().timeIntervalSince1970, forKey: "unlockRequestTimestamp")
    }
}

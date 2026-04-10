//
//  DeviceActivityMonitorExtension.swift
//  dame
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation
import UserNotifications
import os.log

/// Handles two activity types:
/// 1. `mathblocker.daily` — daily budget monitoring. Fires the budget event
///    when the user has used the blocked apps for `budgetMinutes`.
/// 2. `mathblocker.earnedTimer` — calendar timer. `intervalDidEnd` fires
///    after the wall-clock duration that was earned via problem-solving.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: "mathblocker.session")
    )

    private let suiteName = "group.andyjphu.mathblocker"
    private let selectionKey = "activitySelection"

    private let earnedActivityName = "mathblocker.earnedTimer"
    private let budgetEventName = "mathblocker.threshold"

    private static let logger = Logger(
        subsystem: "andyjphu.mathblocker.dame",
        category: "DeviceActivityMonitor"
    )

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Logs to both Apple's unified logging (visible in Xcode console and
    /// Console.app) and to a shared app-group string the main app can
    /// display in its debug view. `.notice` is used so the messages aren't
    /// filtered out by Xcode's default log level.
    private func log(_ message: String) {
        Self.logger.notice("\(message, privacy: .public)")
        let existing = defaults?.string(forKey: "extensionLog") ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        defaults?.set(existing + "\n[\(timestamp)] \(message)", forKey: "extensionLog")
    }

    // MARK: - Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd: \(activity.rawValue)")

        if activity.rawValue == earnedActivityName {
            // Earned timer expired — re-block
            applyShields()
            store.dateAndTime.requireAutomaticDateAndTime = true
            defaults?.removeObject(forKey: "earnedTimerEnd")
            log("earned timer expired, shields applied")
        } else {
            // Daily interval ended — clear all settings
            store.clearAllSettings()
        }
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("eventDidReachThreshold: \(event.rawValue)")

        if event.rawValue == budgetEventName {
            applyShields()
            store.dateAndTime.requireAutomaticDateAndTime = true
            log("budget threshold hit, shields applied")
        }
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        log("eventWillReachThresholdWarning: \(event.rawValue)")

        guard event.rawValue == budgetEventName else { return }

        let lastWarning = defaults?.double(forKey: "lastWarningTimestamp") ?? 0
        let now = Date().timeIntervalSince1970
        guard now - lastWarning > 1800 else {
            log("warning notification skipped (recently sent)")
            return
        }
        defaults?.set(now, forKey: "lastWarningTimestamp")

        sendWarningNotification()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    // MARK: - Notifications

    private func sendWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "5 minutes left"
        content.body = "your blocked apps are about to be locked. open MathBlocker to earn more time."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "threshold-warning",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Shields

    private func applyShields() {
        guard let defaults,
              let data = defaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else { return }

        if !selection.applicationTokens.isEmpty {
            store.shield.applications = selection.applicationTokens
        }
        if !selection.categoryTokens.isEmpty {
            store.shield.applicationCategories = .specific(selection.categoryTokens)
        }
        if !selection.webDomainTokens.isEmpty {
            store.shield.webDomains = selection.webDomainTokens
        }
    }
}

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

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: "mathblocker.session")
    )

    private let suiteName = "group.andyjphu.mathblocker"
    private let selectionKey = "activitySelection"
    private let usageKey = "cumulativeMinutesUsed"
    private let usageDateKey = "usageTrackingDate"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private func log(_ message: String) {
        let existing = defaults?.string(forKey: "extensionLog") ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        defaults?.set(existing + "\n[\(timestamp)] \(message)", forKey: "extensionLog")
    }

    // MARK: - Usage Tracking

    /// Records that the user consumed their full threshold worth of minutes.
    /// Called when threshold fires — at that point, usage = whatever threshold was set.
    private func recordThresholdReached() {
        guard let defaults else { return }

        // Reset if it's a new day
        resetIfNewDay()

        let budget = defaults.integer(forKey: "dailyBudgetMinutes")
        let current = defaults.integer(forKey: usageKey)
        let newTotal = current + max(budget, 1) // add the threshold that was just consumed
        defaults.set(newTotal, forKey: usageKey)
        log("usage updated: \(current) + \(budget) = \(newTotal) minutes")
    }

    /// Resets usage counter at the start of a new day.
    private func resetIfNewDay() {
        guard let defaults else { return }
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let lastDate = defaults.double(forKey: usageDateKey)

        if lastDate < today {
            defaults.set(0, forKey: usageKey)
            defaults.set(today, forKey: usageDateKey)
            log("usage reset for new day")
        }
    }

    // MARK: - Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart: \(activity.rawValue)")
        resetIfNewDay()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd: \(activity.rawValue)")
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("eventDidReachThreshold: \(event.rawValue)")
        recordThresholdReached()
        applyShields()

        // Prevent clock-change bypass
        store.dateAndTime.requireAutomaticDateAndTime = true
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        log("eventWillReachThresholdWarning: \(event.rawValue)")
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

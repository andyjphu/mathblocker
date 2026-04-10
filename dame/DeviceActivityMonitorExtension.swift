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

    /// Records cumulative usage from granular threshold events.
    /// Each event name is "usage.X" where X is total minutes at that threshold.
    /// Only updates if the new value is greater than what's already stored,
    /// to debounce duplicate fires from monitoring restarts.
    private func recordUsage(minutes: Int) {
        guard let defaults else { return }
        resetIfNewDay()

        let current = defaults.integer(forKey: usageKey)
        guard minutes > current else {
            log("usage: \(minutes) (skipped, current is \(current))")
            return
        }

        defaults.set(minutes, forKey: usageKey)
        log("usage: \(minutes) minutes")
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

        let thresholdEventName = "mathblocker.threshold"

        if event.rawValue.hasPrefix("usage."),
           let minutes = Int(event.rawValue.replacingOccurrences(of: "usage.", with: "")) {
            // Granular usage tracking event — update cumulative counter
            recordUsage(minutes: minutes)
        }

        if event.rawValue == thresholdEventName {
            // Debounce: only apply shields if not already active
            if store.shield.applications == nil && store.shield.applicationCategories == nil {
                applyShields()
                store.dateAndTime.requireAutomaticDateAndTime = true
                log("shields applied")
            } else {
                log("shields already active, skipping")
            }
        }
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        log("eventWillReachThresholdWarning: \(event.rawValue)")

        // Only send warning for the budget event, not granular tracking events
        guard event.rawValue == "mathblocker.threshold" else { return }

        // Debounce: only send if last warning was more than 30 min ago
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

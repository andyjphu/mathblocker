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
    private let offsetKey = "monitoringOffset"

    /// Tracking milestones used per monitoring window. Sparse so we stay
    /// well under iOS's ~20-event-per-schedule limit.
    private let trackingMilestones = [1, 5, 15, 30, 60, 90, 120]

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    private func log(_ message: String) {
        let existing = defaults?.string(forKey: "extensionLog") ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        defaults?.set(existing + "\n[\(timestamp)] \(message)", forKey: "extensionLog")
    }

    // MARK: - Usage Tracking

    /// Records cumulative usage. Each event minute is added to the
    /// current monitoring offset to get the absolute total today.
    private func recordUsage(eventMinutes: Int) {
        guard let defaults else { return }
        resetIfNewDay()

        let offset = defaults.integer(forKey: offsetKey)
        let absolute = offset + eventMinutes

        let current = defaults.integer(forKey: usageKey)
        guard absolute > current else {
            log("usage \(absolute) (skipped, current is \(current))")
            return
        }

        defaults.set(absolute, forKey: usageKey)
        log("usage: \(absolute) min (offset \(offset) + event \(eventMinutes))")
    }

    /// Resets usage counter and offset at the start of a new day.
    private func resetIfNewDay() {
        guard let defaults else { return }
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let lastDate = defaults.double(forKey: usageDateKey)

        if lastDate < today {
            defaults.set(0, forKey: usageKey)
            defaults.set(0, forKey: offsetKey)
            defaults.set(today, forKey: usageDateKey)
            log("usage reset for new day")
        }
    }

    // MARK: - Dynamic Re-registration

    /// Restarts monitoring with a fresh window starting from the current
    /// cumulative usage. iOS resets its internal counter on restart, so
    /// we bump the offset by the highest milestone of the prior window.
    private func restartMonitoringFromCurrentPoint() {
        guard let defaults,
              let data = defaults.data(forKey: selectionKey),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
        else {
            log("restart: no selection, skipping")
            return
        }

        let newOffset = defaults.integer(forKey: usageKey)
        let budgetMinutes = defaults.integer(forKey: "dailyBudgetMinutes")

        // Stop current monitoring
        let center = DeviceActivityCenter()
        center.stopMonitoring()

        // Build new events relative to the new starting point
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]

        for minutes in trackingMilestones {
            let eventName = DeviceActivityEvent.Name("usage.\(minutes)")
            events[eventName] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(minute: minutes)
            )
        }

        // Budget event with adjusted threshold
        let remainingBudget = max(1, budgetMinutes - newOffset)
        let budgetEventName = DeviceActivityEvent.Name(rawValue: "mathblocker.threshold")
        events[budgetEventName] = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: remainingBudget)
        )

        let activityName = DeviceActivityName(rawValue: "mathblocker.daily")
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            defaults.set(newOffset, forKey: offsetKey)
            log("restart ok: offset=\(newOffset), remaining budget=\(remainingBudget)")
        } catch {
            log("restart failed: \(error)")
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
            recordUsage(eventMinutes: minutes)

            // If we just hit the highest milestone, restart with a fresh window
            if minutes == trackingMilestones.max() {
                restartMonitoringFromCurrentPoint()
            }
        }

        if event.rawValue == thresholdEventName {
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

        guard event.rawValue == "mathblocker.threshold" else { return }

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

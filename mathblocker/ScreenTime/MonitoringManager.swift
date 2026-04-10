//
//  MonitoringManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import FamilyControls
import Foundation

/// Starts and stops DeviceActivity monitoring schedules.
/// Registers threshold events at 5-minute intervals so the dame extension
/// can track cumulative usage and write it to the app group.
@Observable
class MonitoringManager {
    static let shared = MonitoringManager()

    private let center = DeviceActivityCenter()
    /// Granularity for usage tracking (minutes).
    private let trackingInterval = 5

    var isMonitoring: Bool {
        get { AppGroupConstants.sharedDefaults?.bool(forKey: "isMonitoring") ?? false }
        set { AppGroupConstants.sharedDefaults?.set(newValue, forKey: "isMonitoring") }
    }

    /// Cumulative minutes used today, tracked by the dame extension
    /// via granular threshold events.
    var usedMinutesToday: Int {
        guard let defaults = AppGroupConstants.sharedDefaults else { return 0 }
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        let lastDate = defaults.double(forKey: "usageTrackingDate")
        guard lastDate >= today else { return 0 }
        return defaults.integer(forKey: "cumulativeMinutesUsed")
    }

    func startMonitoring(budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }

        let used = usedMinutesToday

        // Already over budget — block immediately
        if budgetMinutes <= 0 || used >= budgetMinutes {
            ShieldManager.shared.applyShields()
            isMonitoring = true
            syncToAppGroup(budgetMinutes: budgetMinutes)
            print("MonitoringManager: used \(used)m >= budget \(budgetMinutes)m, blocking now")
            return
        }

        let activityName = DeviceActivityName(rawValue: AppGroupConstants.activityName)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        // iOS limits events per schedule (~20 max). Pick a sparse set
        // of milestones that cover a reasonable usage range.
        let trackingMilestones = [1, 5, 10, 15, 30, 45, 60, 90, 120, 180, 240, 360, 480, 600]
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

        // Budget threshold — this is the one that triggers shields
        let budgetEventName = DeviceActivityEvent.Name(rawValue: AppGroupConstants.thresholdEventName)
        events[budgetEventName] = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: budgetMinutes)
        )

        do {
            try center.startMonitoring(activityName, during: schedule, events: events)
            isMonitoring = true
            syncToAppGroup(budgetMinutes: budgetMinutes)
            print("MonitoringManager: started with \(events.count) events, budget \(budgetMinutes)m")
        } catch {
            print("MonitoringManager: failed to start: \(error)")
            isMonitoring = false
        }
    }

    func stopMonitoring() {
        center.stopMonitoring()
        isMonitoring = false
    }

    private func syncToAppGroup(budgetMinutes: Int) {
        let defaults = AppGroupConstants.sharedDefaults
        defaults?.set(budgetMinutes, forKey: AppGroupConstants.budgetMinutesKey)
    }
}

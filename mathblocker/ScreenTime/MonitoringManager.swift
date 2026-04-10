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
/// Uses iOS 26.4's DeviceActivityData.activityData() to read
/// actual usage and set accurate thresholds.
@Observable
class MonitoringManager {
    static let shared = MonitoringManager()

    private let center = DeviceActivityCenter()

    var isMonitoring: Bool {
        get { AppGroupConstants.sharedDefaults?.bool(forKey: "isMonitoring") ?? false }
        set { AppGroupConstants.sharedDefaults?.set(newValue, forKey: "isMonitoring") }
    }

    /// Reads actual usage for today's blocked apps, then starts monitoring
    /// with the correct remaining threshold.
    func startMonitoring(budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }

        if budgetMinutes <= 0 {
            ShieldManager.shared.applyShields()
            isMonitoring = true
            syncToAppGroup(budgetMinutes: 0)
            return
        }

        // Use iOS 26.4 API to get actual usage before setting threshold
        Task { @MainActor in
            let usedMinutes = self.readUsageFromAppGroup()

            if usedMinutes >= budgetMinutes {
                // Already over budget — block immediately
                ShieldManager.shared.applyShields()
                self.isMonitoring = true
                self.syncToAppGroup(budgetMinutes: budgetMinutes)
                print("MonitoringManager: usage \(usedMinutes)m >= budget \(budgetMinutes)m, blocking now")
                return
            }

            let remaining = budgetMinutes - usedMinutes
            print("MonitoringManager: usage \(usedMinutes)m, budget \(budgetMinutes)m, threshold \(remaining)m")
            self.startMonitoringWithThreshold(remaining: remaining, budgetMinutes: budgetMinutes)
        }
    }

    private func startMonitoringWithThreshold(remaining: Int, budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        let activityName = DeviceActivityName(rawValue: AppGroupConstants.activityName)
        let eventName = DeviceActivityEvent.Name(rawValue: AppGroupConstants.thresholdEventName)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: min(5, remaining))
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: remaining)
        )

        do {
            try center.startMonitoring(activityName, during: schedule, events: [eventName: event])
            isMonitoring = true
            syncToAppGroup(budgetMinutes: budgetMinutes)
        } catch {
            print("MonitoringManager: failed to start: \(error)")
            isMonitoring = false
        }
    }

    /// Reads usage minutes written by the report extension via app group.
    private func readUsageFromAppGroup() -> Int {
        guard let defaults = AppGroupConstants.sharedDefaults else { return 0 }
        let timestamp = defaults.double(forKey: "reportUsedTimestamp")
        let today = Calendar.current.startOfDay(for: .now).timeIntervalSince1970
        guard timestamp >= today else { return 0 }
        return defaults.integer(forKey: "reportUsedMinutesToday")
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

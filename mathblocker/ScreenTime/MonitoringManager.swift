//
//  MonitoringManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings
import SwiftUI

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
            let usedMinutes: Int
            if #available(iOS 26.4, *) {
                usedMinutes = await self.fetchTodayUsageMinutes()
            } else {
                usedMinutes = 0
            }

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

    /// Fetches today's total usage on blocked apps using iOS 26.4 API.
    @available(iOS 26.4, *)
    private func fetchTodayUsageMinutes() async -> Int {
        let today = Calendar.current.startOfDay(for: .now)
        let now = Date.now
        let selection = SelectionManager.shared.selection

        let filter = DeviceActivityFilter(
            segment: .hourly(during: DateInterval(start: today, end: now)),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )

        var totalSeconds: TimeInterval = 0

        do {
            for try await activityData in DeviceActivityData.activityData(filteredBy: filter, using: .cached) {
                for await segment in activityData.activitySegments {
                    for await category in segment.categories {
                        for await app in category.applications {
                            totalSeconds += app.totalActivityDuration
                        }
                    }
                }
            }
        } catch {
            print("MonitoringManager: failed to fetch usage: \(error)")
        }

        return Int(totalSeconds / 60)
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

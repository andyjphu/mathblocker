//
//  MonitoringManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import FamilyControls
import Foundation

@Observable
class MonitoringManager {
    static let shared = MonitoringManager()

    private let center = DeviceActivityCenter()

    var isMonitoring = false

    func startMonitoring(budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }

        let activityName = DeviceActivityName(rawValue: AppGroupConstants.activityName)
        let eventName = DeviceActivityEvent.Name(rawValue: AppGroupConstants.thresholdEventName)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: budgetMinutes)
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

    func stopMonitoring() {
        center.stopMonitoring()
        isMonitoring = false
    }

    private func syncToAppGroup(budgetMinutes: Int) {
        let defaults = AppGroupConstants.sharedDefaults
        defaults?.set(budgetMinutes, forKey: AppGroupConstants.budgetMinutesKey)
    }
}

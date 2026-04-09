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

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: "mathblocker.session")
    )

    private let suiteName = "group.andyjphu.mathblocker"
    private let selectionKey = "activitySelection"

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.clearAllSettings()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        applyShields()
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    private func applyShields() {
        guard let defaults = UserDefaults(suiteName: suiteName),
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

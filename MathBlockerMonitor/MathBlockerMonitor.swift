//
//  MathBlockerMonitor.swift
//  MathBlockerMonitor
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import ManagedSettings
import FamilyControls
import Foundation

class MathBlockerMonitor: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: "mathblocker.session")
    )

    private let suiteName = "group.andyjphu.mathblocker"
    private let selectionKey = "activitySelection"

    // Called when the monitoring interval starts (start of day)
    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        // Optionally apply shields at start of day if desired
    }

    // Called when the monitoring interval ends (end of day)
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Reset shields at end of day
        store.clearAllSettings()
    }

    // Called when usage threshold is hit — this is the core trigger
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        applyShields()
    }

    // Called shortly before threshold (warning)
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        // Could send a local notification here
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

//
//  DebugSection.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import DeviceActivity
import SwiftData

/// Development-only section showing extension logs, monitoring state,
/// and app group data. Helps diagnose shield/monitoring issues on-device.
struct DebugSection: View {
    @Query private var settings: [UserSettings]
    @State private var debugInfo: String = ""
    @State private var debugLog: String = ""

    var body: some View {
        Section {
            Text(debugInfo)
                .font(.caption)

            Text(debugLog)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("refresh") {
                loadDebugInfo()
            }

            Button("clear log") {
                AppGroupConstants.sharedDefaults?.removeObject(forKey: "extensionLog")
                debugLog = "cleared"
            }

            Button("force re-register monitoring") {
                // Tear down any existing schedule and start fresh with the
                // current settings. This is the nuclear-option recovery if
                // iOS is in a weird state (stale schedule, counter mismatch).
                MonitoringManager.shared.stopMonitoring()
                let budget = settings.first?.dailyTimeBudgetMinutes ?? 30
                MonitoringManager.shared.startMonitoring(budgetMinutes: budget)
                loadDebugInfo()
            }
        } header: {
            Text("debug")
        }
        .onAppear { loadDebugInfo() }
    }

    private func loadDebugInfo() {
        let defaults = AppGroupConstants.sharedDefaults
        let budget = defaults?.integer(forKey: AppGroupConstants.budgetMinutesKey) ?? -1
        let hasSelection = defaults?.data(forKey: AppGroupConstants.selectionKey) != nil
        let log = defaults?.string(forKey: "extensionLog") ?? "no logs yet"
        let monitoring = MonitoringManager.shared.isMonitoring

        debugInfo = """
        monitoring: \(monitoring ? "on" : "off")
        budget: \(budget) min
        selection saved: \(hasSelection ? "yes" : "no")
        """
        debugLog = log

        Task {
            let activities = DeviceActivityCenter().activities.map(\.rawValue).joined(separator: ", ")
            await MainActor.run {
                debugInfo += "\nactivities: \(activities.isEmpty ? "none" : activities)"
            }
        }
    }
}

//
//  AppGroupConstants.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// Shared keys and identifiers used by both the main app and extensions
/// to communicate via the app group UserDefaults.
enum AppGroupConstants {
    static let suiteName = "group.andyjphu.mathblocker"
    static let selectionKey = "activitySelection"
    static let budgetMinutesKey = "dailyBudgetMinutes"
    static let minutesPerCorrectKey = "minutesPerCorrect"
    static let shieldStoreName = "mathblocker.session"
    static let activityName = "mathblocker.daily"
    static let thresholdEventName = "mathblocker.threshold"
    static let urlScheme = "mathblocker"
    static let diagnosticLogKey = "extensionLog"
    static let bankedMinutesKey = "bankedMinutes"
    static let lastStartedBudgetMinutesKey = "lastStartedBudgetMinutes"
    static let budgetHitDateKey = "budgetHitDate"
    static let budgetHitThresholdKey = "budgetHitThreshold"
    private static let diagnosticLogMaxLines = 300

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Appends a main-app diagnostic line to the shared log (same key dame
    /// writes to). Entries are prefixed with `main:` so they can be told
    /// apart from dame's entries when reading the unified log in the bug
    /// report view. Capped at 300 lines.
    static func appendDiagnosticLog(_ message: String) {
        guard let defaults = sharedDefaults else { return }
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let entry = "[\(timestamp)] main: \(message)"
        let existing = defaults.string(forKey: diagnosticLogKey) ?? ""
        var combined = existing.isEmpty ? entry : existing + "\n" + entry

        let lines = combined.split(separator: "\n", omittingEmptySubsequences: false)
        if lines.count > diagnosticLogMaxLines {
            combined = lines.suffix(diagnosticLogMaxLines).joined(separator: "\n")
        }
        defaults.set(combined, forKey: diagnosticLogKey)
    }
}

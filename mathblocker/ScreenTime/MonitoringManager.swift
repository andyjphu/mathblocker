//
//  MonitoringManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import FamilyControls
import Foundation

/// Manages two kinds of monitoring schedules:
/// 1. Daily budget — a screen-time threshold event that fires when the
///    user has used the blocked apps for `budgetMinutes`.
/// 2. Earned timer — a calendar-time schedule that fires `intervalDidEnd`
///    after a fixed wall-clock duration. Used after the user solves
///    problems to grant a finite window of additional access.
@Observable
class MonitoringManager {
    static let shared = MonitoringManager()

    @ObservationIgnored
    private let center = DeviceActivityCenter()

    @ObservationIgnored
    private let budgetActivity = DeviceActivityName(rawValue: "mathblocker.daily")
    @ObservationIgnored
    private let earnedActivity = DeviceActivityName(rawValue: "mathblocker.earnedTimer")

    /// Stored property so that SwiftUI's `@Observable` tracking picks up
    /// changes. We keep the UserDefaults write as the cross-process source
    /// of truth and sync this stored value on every write / on scene resume.
    private(set) var earnedTimerEnd: Date?

    /// `isMonitoring` lives in the app group so the monitoring extension
    /// can read/write it. Observability for this flag currently relies on
    /// scene-phase refresh — see `refreshFromStorage()`.
    var isMonitoring: Bool {
        get { AppGroupConstants.sharedDefaults?.bool(forKey: "isMonitoring") ?? false }
        set { AppGroupConstants.sharedDefaults?.set(newValue, forKey: "isMonitoring") }
    }

    @ObservationIgnored
    private var expiryTimer: Timer?

    init() {
        // Restore earned-timer state from UserDefaults on launch so the
        // dashboard shows the correct countdown after a cold start.
        refreshFromStorage()
    }

    /// Re-read the earned timer end from UserDefaults and publish it via
    /// the observable `earnedTimerEnd` property. Call this on app foreground
    /// or after any external change.
    @MainActor
    func refreshFromStorage() {
        let timestamp = AppGroupConstants.sharedDefaults?.double(forKey: "earnedTimerEnd") ?? 0
        let now = Date.now.timeIntervalSince1970
        if timestamp > now {
            setEarnedTimerEnd(Date(timeIntervalSince1970: timestamp))
        } else {
            setEarnedTimerEnd(nil)
        }
    }

    /// Updates the observable `earnedTimerEnd` and schedules (or cancels)
    /// the local Timer that clears it once the wall-clock deadline passes,
    /// so the dashboard automatically flips back to the "earned today" state
    /// without needing a manual refresh.
    @MainActor
    private func setEarnedTimerEnd(_ date: Date?) {
        earnedTimerEnd = date
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let end = date else { return }
        let interval = end.timeIntervalSinceNow
        guard interval > 0 else {
            earnedTimerEnd = nil
            return
        }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.earnedTimerEnd = nil
            }
        }
    }

    // MARK: - Daily Budget

    /// Starts daily budget monitoring. iOS will track usage of the user's
    /// selected apps and fire the budget event when usage hits `budgetMinutes`.
    func startMonitoring(budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }

        if budgetMinutes <= 0 {
            ShieldManager.shared.applyShields()
            isMonitoring = true
            syncBudgetToAppGroup(budgetMinutes)
            return
        }

        ShieldManager.shared.removeShields()

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        let budgetEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: budgetMinutes)
        )

        let eventName = DeviceActivityEvent.Name(rawValue: AppGroupConstants.thresholdEventName)

        do {
            try center.startMonitoring(budgetActivity, during: schedule, events: [eventName: budgetEvent])
            isMonitoring = true
            syncBudgetToAppGroup(budgetMinutes)
        } catch {
            print("MonitoringManager: failed to start budget monitoring: \(error)")
            isMonitoring = false
        }
    }

    func stopMonitoring() {
        center.stopMonitoring()
        isMonitoring = false
        clearEarnedTimer()
    }

    // MARK: - Earned Timer (Calendar Time)

    /// Grants the user `minutes` of wall-clock time before shields re-apply.
    /// If a timer is already running, the new minutes stack on top of the
    /// remaining time so the user never loses earned credit.
    func startEarnedTimer(minutes: Int) {
        guard minutes > 0 else { return }

        let now = Date.now

        // Stack on top of any existing timer
        let existingEnd = AppGroupConstants.sharedDefaults?.double(forKey: "earnedTimerEnd") ?? 0
        let remaining: TimeInterval
        if existingEnd > now.timeIntervalSince1970 {
            remaining = existingEnd - now.timeIntervalSince1970
        } else {
            remaining = 0
        }

        let totalSeconds = remaining + TimeInterval(minutes * 60)
        let endDate = now.addingTimeInterval(totalSeconds)

        // Stop any existing timer schedule
        center.stopMonitoring([earnedActivity])

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: endDate
        )

        let schedule = DeviceActivitySchedule(
            intervalStart: startComponents,
            intervalEnd: endComponents,
            repeats: false
        )

        do {
            try center.startMonitoring(earnedActivity, during: schedule, events: [:])
            AppGroupConstants.sharedDefaults?.set(endDate.timeIntervalSince1970, forKey: "earnedTimerEnd")
            ShieldManager.shared.removeShields()
            print("MonitoringManager: earned timer ends at \(endDate)")
        } catch {
            print("MonitoringManager: failed to start earned timer: \(error)")
        }
    }

    private func clearEarnedTimer() {
        center.stopMonitoring([earnedActivity])
        AppGroupConstants.sharedDefaults?.removeObject(forKey: "earnedTimerEnd")
    }

    private func syncBudgetToAppGroup(_ minutes: Int) {
        AppGroupConstants.sharedDefaults?.set(minutes, forKey: AppGroupConstants.budgetMinutesKey)
    }
}

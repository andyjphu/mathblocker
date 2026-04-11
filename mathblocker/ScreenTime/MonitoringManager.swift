//
//  MonitoringManager.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import FamilyControls
import Foundation
import os.log

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
    private static let logger = Logger(
        subsystem: "andyjphu.mathblocker",
        category: "MonitoringManager"
    )

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
        // dashboard shows the correct countdown after a cold start. Direct
        // assignment here to avoid crossing actor boundaries from init.
        let timestamp = AppGroupConstants.sharedDefaults?.double(forKey: "earnedTimerEnd") ?? 0
        if timestamp > Date.now.timeIntervalSince1970 {
            self.earnedTimerEnd = Date(timeIntervalSince1970: timestamp)
            // Schedule expiry via a main-actor hop since Timer must be on main.
            Task { @MainActor in
                MonitoringManager.shared.scheduleExpiryTimer()
            }
        }
    }

    /// Re-read the earned timer end from UserDefaults and publish it via
    /// the observable `earnedTimerEnd` property. Call this on app foreground
    /// or after any external change.
    ///
    /// Also reconciles shield state. Two recovery paths:
    /// - If a stored `earnedTimerEnd` is already in the past, the timer
    ///   expired while the app was backgrounded. dame's extension *should*
    ///   have re-applied shields via `intervalDidEnd`, but its schedule
    ///   registration may have failed in the first place. Re-apply from
    ///   the main app as a fallback.
    /// - If dame logged `budgetHitDate` for today and there's no active
    ///   earned timer, the user is over budget and shields should be up.
    ///   Reapply if they've silently dropped.
    @MainActor
    func refreshFromStorage() {
        let defaults = AppGroupConstants.sharedDefaults
        let timestamp = defaults?.double(forKey: "earnedTimerEnd") ?? 0
        let now = Date.now.timeIntervalSince1970

        if timestamp > now {
            setEarnedTimerEnd(Date(timeIntervalSince1970: timestamp))
        } else {
            if timestamp > 0 {
                // Timer was set at some point but has since expired.
                // Reapply shields defensively in case dame didn't.
                Self.logger.notice("refreshFromStorage: expired earnedTimerEnd (\(timestamp, privacy: .public)), reapplying shields")
                ShieldManager.shared.applyShields()
                defaults?.removeObject(forKey: "earnedTimerEnd")
            }
            setEarnedTimerEnd(nil)
            reconcileShieldsWithBudget()
        }
    }

    /// If dame has logged that today's budget was blown and there's no
    /// active earned timer, the user should be shielded. Reapply if
    /// `ShieldManager` says shields are currently off.
    @MainActor
    private func reconcileShieldsWithBudget() {
        guard earnedTimerEnd == nil else { return }
        let defaults = AppGroupConstants.sharedDefaults
        guard let hitDateString = defaults?.string(forKey: "budgetHitDate") else { return }
        let todayString = MonitoringManager.todayKey()
        guard hitDateString == todayString else { return }

        ShieldManager.shared.refreshState()
        if !ShieldManager.shared.shieldsAreActive {
            Self.logger.notice("reconcileShieldsWithBudget: budget was hit today (\(hitDateString, privacy: .public)) but shields are off, reapplying")
            ShieldManager.shared.applyShields()
        }
    }

    /// `yyyy-MM-dd` string for the current local day, used as the
    /// cross-process key for "budget was hit today" signalling.
    static func todayKey() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        return fmt.string(from: Date())
    }

    /// Schedules the Timer that clears `earnedTimerEnd` when the wall-clock
    /// deadline passes, so the dashboard flips back to the "time's up" view
    /// and shields are re-applied by the main app even if dame's
    /// `intervalDidEnd` callback never fires (e.g. the earned-timer
    /// schedule failed to register on iOS in the first place).
    @MainActor
    private func scheduleExpiryTimer() {
        expiryTimer?.invalidate()
        expiryTimer = nil
        guard let end = earnedTimerEnd else { return }
        let interval = end.timeIntervalSinceNow
        guard interval > 0 else {
            earnedTimerEnd = nil
            ShieldManager.shared.applyShields()
            return
        }
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                MonitoringManager.shared.earnedTimerEnd = nil
                // Main-app-side shield reapply — belt to dame's suspenders.
                ShieldManager.shared.applyShields()
                Self.logger.notice("earned timer expired in main app, shields reapplied")
            }
        }
    }

    /// Updates the observable `earnedTimerEnd` and schedules (or cancels)
    /// the local Timer that clears it once the wall-clock deadline passes,
    /// so the dashboard automatically flips back to the "earned today" state
    /// without needing a manual refresh.
    @MainActor
    private func setEarnedTimerEnd(_ date: Date?) {
        earnedTimerEnd = date
        scheduleExpiryTimer()
    }

    // MARK: - Daily Budget

    /// Starts daily budget monitoring. iOS will track usage of the user's
    /// selected apps and fire the budget event when usage hits `budgetMinutes`.
    ///
    /// `DeviceActivityCenter.startMonitoring` has a nasty side effect: **iOS
    /// resets the internal event counter every time it's called with the
    /// same activity name**. So naïvely calling this on every stepper tick
    /// or every relaunch silently gifts the user a fresh budget.
    ///
    /// To keep the counter intact, we guard against duplicate calls: if
    /// monitoring is already active with the same budget and the same set
    /// of selected apps, we no-op. The caller (e.g. settings toggle) can
    /// force a restart by calling `stopMonitoring()` first.
    ///
    /// We also no longer unconditionally drop shields on restart — that
    /// let users bypass an active shield just by bumping the stepper.
    func startMonitoring(budgetMinutes: Int) {
        let selection = SelectionManager.shared.selection
        let appCount = selection.applicationTokens.count
        let catCount = selection.categoryTokens.count
        Self.logger.notice("startMonitoring called: budgetMinutes=\(budgetMinutes, privacy: .public), apps=\(appCount, privacy: .public), categories=\(catCount, privacy: .public)")
        guard appCount > 0 || catCount > 0 else {
            Self.logger.notice("startMonitoring: empty selection, bailing out")
            return
        }

        // FamilyActivitySelection isn't Hashable; use its JSON encoding as a
        // stable fingerprint for change detection. Encoding failure falls back
        // to "always restart" which is safe.
        let selectionFingerprint = (try? JSONEncoder().encode(selection))?.hashValue

        if budgetMinutes <= 0 {
            ShieldManager.shared.applyShields()
            isMonitoring = true
            syncBudgetToAppGroup(budgetMinutes)
            lastStartedBudgetMinutes = 0
            lastStartedSelectionHash = selectionFingerprint
            Self.logger.notice("startMonitoring: budget<=0, applied shields immediately")
            return
        }

        // Idempotency guard: if we already started monitoring today with the
        // exact same budget and selection, don't restart — that would reset
        // iOS's usage counter.
        if isMonitoring,
           lastStartedBudgetMinutes == budgetMinutes,
           let fp = selectionFingerprint,
           lastStartedSelectionHash == fp {
            syncBudgetToAppGroup(budgetMinutes)
            Self.logger.notice("startMonitoring: idempotency skip (same budget and selection already registered)")
            return
        }

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )

        // `includesPastActivity: true` tells iOS to count the user's screen
        // time from the interval start (midnight) rather than from the moment
        // this call was made. Without this, any restart of monitoring (app
        // launch, settings toggle, stepper change) silently gifts the user a
        // fresh budget because iOS throws away all usage before the restart.
        // Added in iOS 17.4 — see Apple's `DeviceActivityEvent` docs.
        let budgetEvent = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: selection.webDomainTokens,
            threshold: DateComponents(minute: budgetMinutes),
            includesPastActivity: true
        )

        let eventName = DeviceActivityEvent.Name(rawValue: AppGroupConstants.thresholdEventName)

        do {
            try center.startMonitoring(budgetActivity, during: schedule, events: [eventName: budgetEvent])
            isMonitoring = true
            syncBudgetToAppGroup(budgetMinutes)
            lastStartedBudgetMinutes = budgetMinutes
            lastStartedSelectionHash = selectionFingerprint
            let registered = center.activities.map(\.rawValue).joined(separator: ",")
            Self.logger.notice("startMonitoring: registered budget event, threshold=\(budgetMinutes, privacy: .public) min, includesPastActivity=true, center.activities=[\(registered, privacy: .public)]")
        } catch {
            Self.logger.error("startMonitoring: center.startMonitoring threw: \(error.localizedDescription, privacy: .public)")
            isMonitoring = false
        }
    }

    /// Remembers the budget + selection we last registered with iOS so we
    /// can avoid re-registering (which resets the counter).
    @ObservationIgnored
    private var lastStartedBudgetMinutes: Int?
    @ObservationIgnored
    private var lastStartedSelectionHash: Int?

    func stopMonitoring() {
        Self.logger.notice("stopMonitoring called, tearing down all DeviceActivity schedules")
        center.stopMonitoring()
        isMonitoring = false
        lastStartedBudgetMinutes = nil
        lastStartedSelectionHash = nil
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

        // Commit UI state up front so the dashboard countdown shows even if
        // the iOS DeviceActivitySchedule registration fails (e.g. in the
        // simulator without full FamilyControls auth). The schedule is only
        // needed so that `dame` can re-apply shields when the timer expires;
        // the countdown itself is pure wall-clock and doesn't depend on it.
        let defaults = AppGroupConstants.sharedDefaults
        defaults?.set(endDate.timeIntervalSince1970, forKey: "earnedTimerEnd")
        // Round-trip verification: did the write actually persist?
        let readBack = defaults?.double(forKey: "earnedTimerEnd") ?? 0
        Self.logger.notice("startEarnedTimer: wrote \(endDate.timeIntervalSince1970, privacy: .public), read back \(readBack, privacy: .public), match=\(abs(readBack - endDate.timeIntervalSince1970) < 0.001, privacy: .public), defaults=\(defaults != nil, privacy: .public)")
        Task { @MainActor in
            setEarnedTimerEnd(endDate)
        }
        ShieldManager.shared.removeShields()

        do {
            try center.startMonitoring(earnedActivity, during: schedule, events: [:])
            Self.logger.notice("earned timer registered, ends at \(endDate, privacy: .public)")
        } catch {
            // UI state is already committed above; log and continue.
            Self.logger.error("failed to register earned timer schedule (countdown will still show, but shields may not re-apply at expiry): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func clearEarnedTimer() {
        center.stopMonitoring([earnedActivity])
        AppGroupConstants.sharedDefaults?.removeObject(forKey: "earnedTimerEnd")
        Task { @MainActor in
            setEarnedTimerEnd(nil)
        }
    }

    private func syncBudgetToAppGroup(_ minutes: Int) {
        AppGroupConstants.sharedDefaults?.set(minutes, forKey: AppGroupConstants.budgetMinutesKey)
    }
}

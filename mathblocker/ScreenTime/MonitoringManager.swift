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

    /// Minutes the user has solved math for while *not* over budget, stored
    /// for redemption when the budget threshold eventually fires. Backed by
    /// the app group so `dame` can read and clear it when applying shields.
    private(set) var bankedMinutes: Int = 0

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
        self.bankedMinutes = AppGroupConstants.sharedDefaults?.integer(forKey: AppGroupConstants.bankedMinutesKey) ?? 0

        // Restore the last-started budget so "budget raised → drop shields"
        // detection works across app relaunches. Without this, the first
        // budget change after a cold launch always sees `prevBudget=nil`
        // and silently skips the drop-shields branch.
        //
        // First-launch migration: if the key is absent but a `budgetHitDate`
        // exists, we're on the first boot of a build that persists
        // `lastStartedBudgetMinutes`. The pre-existing `budgetHitDate`
        // references an old budget threshold we can't verify against the
        // current budget, so clear it — the main app's reconcile path will
        // then drop shields if the user is under their current budget, and
        // dame will re-fire if they're still over.
        let defaults = AppGroupConstants.sharedDefaults
        if let stored = defaults?.object(forKey: AppGroupConstants.lastStartedBudgetMinutesKey) as? Int {
            self.lastStartedBudgetMinutes = stored
        } else {
            if defaults?.string(forKey: AppGroupConstants.budgetHitDateKey) != nil {
                AppGroupConstants.appendDiagnosticLog("init: migration — no persisted lastStartedBudgetMinutes but budgetHitDate is set; clearing so next reconcile re-evaluates")
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitDateKey)
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitThresholdKey)
            }
            // Write the sentinel so next launch skips the migration branch.
            defaults?.set(0, forKey: AppGroupConstants.lastStartedBudgetMinutesKey)
            self.lastStartedBudgetMinutes = 0
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

        // Pick up any banked-minute changes made by dame (e.g. it redeemed
        // banked time on threshold fire and cleared the key).
        let storedBanked = defaults?.integer(forKey: AppGroupConstants.bankedMinutesKey) ?? 0
        if storedBanked != bankedMinutes {
            bankedMinutes = storedBanked
        }

        ShieldManager.shared.refreshState()

        if timestamp > now {
            // Active earned timer: shields should be OFF. If they drifted
            // on for any reason, drop them explicitly so the user doesn't
            // have to wait for the next dame event to unblock.
            setEarnedTimerEnd(Date(timeIntervalSince1970: timestamp))
            if ShieldManager.shared.shieldsAreActive {
                AppGroupConstants.appendDiagnosticLog("refreshFromStorage: active earned timer but shields on, removing")
                ShieldManager.shared.removeShields(reason: "refresh-active-timer")
            }
        } else {
            if timestamp > 0 {
                // Timer was set at some point but has since expired.
                // Reapply shields defensively in case dame didn't.
                Self.logger.notice("refreshFromStorage: expired earnedTimerEnd (\(timestamp, privacy: .public)), reapplying shields")
                AppGroupConstants.appendDiagnosticLog("refreshFromStorage: expired earnedTimerEnd, reapplying shields")
                ShieldManager.shared.applyShields(reason: "refreshFromStorage-expired-timer")
                defaults?.removeObject(forKey: "earnedTimerEnd")
            }
            setEarnedTimerEnd(nil)
            reconcileShieldsWithBudget()
        }
    }

    /// Add `minutes` to the user's banked stash. Banked minutes are
    /// redeemed by `dame` when the daily budget threshold fires: dame
    /// registers an earned timer for the banked amount *instead of*
    /// applying shields, letting the user spend their math-earned time
    /// before they get blocked.
    func bankMinutes(_ minutes: Int) {
        guard minutes > 0 else { return }
        let defaults = AppGroupConstants.sharedDefaults
        let current = defaults?.integer(forKey: AppGroupConstants.bankedMinutesKey) ?? 0
        let newTotal = current + minutes
        defaults?.set(newTotal, forKey: AppGroupConstants.bankedMinutesKey)
        Task { @MainActor in
            self.bankedMinutes = newTotal
        }
        AppGroupConstants.appendDiagnosticLog("bankMinutes: added \(minutes), new total=\(newTotal)")
        Self.logger.notice("bankMinutes: +\(minutes, privacy: .public), total=\(newTotal, privacy: .public)")
    }

    /// Bidirectional shield reconciliation when there's no active earned
    /// timer. Decides from budget signals and converges `ShieldManager`
    /// to the right state — apply if should be on, remove if should be off.
    /// This is the "open app, be in the right state immediately" path.
    @MainActor
    private func reconcileShieldsWithBudget() {
        guard earnedTimerEnd == nil else { return }
        let defaults = AppGroupConstants.sharedDefaults
        let hitDateString = defaults?.string(forKey: "budgetHitDate")
        let todayString = MonitoringManager.todayKey()
        let budget = defaults?.integer(forKey: AppGroupConstants.budgetMinutesKey) ?? 0

        ShieldManager.shared.refreshState()
        let currentlyActive = ShieldManager.shared.shieldsAreActive

        // Zero budget = block unconditionally (user explicitly wants zero
        // free time per day, math-only access).
        if budget <= 0 && isMonitoring {
            if !currentlyActive {
                AppGroupConstants.appendDiagnosticLog("reconcile: zero budget, applying shields")
                ShieldManager.shared.applyShields(reason: "reconcile-zero-budget")
            }
            return
        }

        if hitDateString == todayString {
            // Budget was blown today. But was it blown at the *current*
            // budget, or at an older (lower) threshold that the user has
            // since raised past? Compare against `budgetHitThreshold`: if
            // the user's current budget is higher than the threshold that
            // fired, the hit is obsolete and shields should drop.
            let hitThreshold = defaults?.integer(forKey: AppGroupConstants.budgetHitThresholdKey) ?? 0
            if hitThreshold > 0 && budget > hitThreshold {
                AppGroupConstants.appendDiagnosticLog("reconcile: stale hit — budgetHitThreshold=\(hitThreshold) but current budget=\(budget), clearing hit and dropping shields")
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitDateKey)
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitThresholdKey)
                if currentlyActive && isMonitoring {
                    ShieldManager.shared.removeShields(reason: "reconcile-obsolete-hit-\(hitThreshold)-to-\(budget)")
                }
                return
            }

            // Hit is fresh. Shields should be ON.
            if !currentlyActive {
                Self.logger.notice("reconcile: budget hit today but shields are off, reapplying")
                AppGroupConstants.appendDiagnosticLog("reconcile: budget hit today but shields off, reapplying")
                ShieldManager.shared.applyShields(reason: "reconcile-budgetHitToday")
            }
        } else {
            // No budget hit today, no active timer → user is under budget.
            // Shields should be OFF. This fires on "open app after new
            // day rollover" and "open app after raising budget" so the
            // user doesn't wait for dame's next event to unblock.
            //
            // Also clear any stale `budgetHitDate` / `budgetHitThreshold`
            // lingering from a previous day so dame's earnedTimer
            // `intervalDidEnd` guards see a clean state and don't
            // re-apply shields when a padded schedule outlasts
            // midnight rollover.
            if hitDateString != nil {
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitDateKey)
                defaults?.removeObject(forKey: AppGroupConstants.budgetHitThresholdKey)
                AppGroupConstants.appendDiagnosticLog("reconcile: cleared stale budgetHitDate=\(hitDateString ?? "")")
            }
            if currentlyActive && isMonitoring {
                AppGroupConstants.appendDiagnosticLog("reconcile: no budget hit today, shields were on, removing")
                ShieldManager.shared.removeShields(reason: "reconcile-no-budget-hit")
            }
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
            AppGroupConstants.appendDiagnosticLog("scheduleExpiryTimer: end already in past, reapplying shields immediately")
            ShieldManager.shared.applyShields(reason: "expiry-already-past")
            return
        }
        AppGroupConstants.appendDiagnosticLog("scheduleExpiryTimer: in-app Timer scheduled for \(Int(interval))s")
        expiryTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                MonitoringManager.shared.earnedTimerEnd = nil
                AppGroupConstants.appendDiagnosticLog("earned timer expired in main app, reapplying shields")
                // Main-app-side shield reapply — belt to dame's suspenders.
                ShieldManager.shared.applyShields(reason: "earned-timer-expiry")
                Self.logger.notice("earned timer expired in main app, shields reapplied")
            }
        }
    }

    /// Updates the observable `earnedTimerEnd` and schedules (or cancels)
    /// the local Timer that clears it once the wall-clock deadline passes,
    /// so the dashboard automatically flips back to the "earned today" state
    /// without needing a manual refresh.
    ///
    /// Idempotent: if the new date is within 1 second of the current value
    /// we skip the re-schedule, so the dashboard's 2-second `refreshFromStorage`
    /// poll doesn't repeatedly invalidate and recreate the expiry Timer.
    @MainActor
    private func setEarnedTimerEnd(_ date: Date?) {
        switch (earnedTimerEnd, date) {
        case (nil, nil):
            return
        case (let current?, let new?) where abs(current.timeIntervalSince(new)) < 1:
            return
        default:
            break
        }
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
        let previousBudget = lastStartedBudgetMinutes
        Self.logger.notice("startMonitoring called: budgetMinutes=\(budgetMinutes, privacy: .public), apps=\(appCount, privacy: .public), categories=\(catCount, privacy: .public)")
        AppGroupConstants.appendDiagnosticLog("startMonitoring called budgetMinutes=\(budgetMinutes) apps=\(appCount) cats=\(catCount) prevBudget=\(previousBudget.map(String.init) ?? "nil")")
        guard appCount > 0 || catCount > 0 else {
            Self.logger.notice("startMonitoring: empty selection, bailing out")
            AppGroupConstants.appendDiagnosticLog("startMonitoring: empty selection, bailing out")
            return
        }

        // FamilyActivitySelection isn't Hashable; use its JSON encoding as a
        // stable fingerprint for change detection. Encoding failure falls back
        // to "always restart" which is safe.
        let selectionFingerprint = (try? JSONEncoder().encode(selection))?.hashValue

        if budgetMinutes <= 0 {
            ShieldManager.shared.applyShields(reason: "startMonitoring-zero-budget")
            isMonitoring = true
            syncBudgetToAppGroup(budgetMinutes)
            lastStartedBudgetMinutes = 0
            lastStartedSelectionHash = selectionFingerprint
            AppGroupConstants.sharedDefaults?.set(0, forKey: AppGroupConstants.lastStartedBudgetMinutesKey)
            Self.logger.notice("startMonitoring: budget<=0, applied shields immediately")
            AppGroupConstants.appendDiagnosticLog("startMonitoring: budget<=0, applied shields immediately")
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
            AppGroupConstants.appendDiagnosticLog("startMonitoring: idempotency skip")
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
            // Persist across app relaunches so budget-raise detection
            // survives the MonitoringManager singleton being re-initialized.
            AppGroupConstants.sharedDefaults?.set(budgetMinutes, forKey: AppGroupConstants.lastStartedBudgetMinutesKey)
            let registered = center.activities.map(\.rawValue).joined(separator: ",")
            Self.logger.notice("startMonitoring: registered budget event, threshold=\(budgetMinutes, privacy: .public) min, includesPastActivity=true, center.activities=[\(registered, privacy: .public)]")
            AppGroupConstants.appendDiagnosticLog("startMonitoring: registered threshold=\(budgetMinutes)min includesPastActivity=true activities=[\(registered)]")

            // If the user raised their budget, they're explicitly asking
            // for more free time. Drop shields so the new (higher)
            // threshold gets a chance to evaluate cleanly. If they're
            // still over the new threshold, iOS will re-fire
            // `eventDidReachThreshold` within seconds and dame will
            // reapply. If they're now under, shields stay off and the
            // next math-earn will bank instead of redeem.
            if let old = previousBudget, budgetMinutes > old {
                AppGroupConstants.appendDiagnosticLog("startMonitoring: budget raised \(old)→\(budgetMinutes), clearing budgetHitDate and dropping shields so new threshold re-evaluates")
                AppGroupConstants.sharedDefaults?.removeObject(forKey: "budgetHitDate")
                ShieldManager.shared.removeShields(reason: "budget-raised-\(old)-to-\(budgetMinutes)")
            }
        } catch {
            Self.logger.error("startMonitoring: center.startMonitoring threw: \(error.localizedDescription, privacy: .public)")
            AppGroupConstants.appendDiagnosticLog("startMonitoring THREW: \(error.localizedDescription)")
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
        AppGroupConstants.appendDiagnosticLog("stopMonitoring called, tearing down schedules")
        center.stopMonitoring()
        isMonitoring = false
        lastStartedBudgetMinutes = nil
        lastStartedSelectionHash = nil
        // Clear the persisted last budget too; any subsequent `startMonitoring`
        // should be a fresh start, not a comparison against stale data.
        AppGroupConstants.sharedDefaults?.removeObject(forKey: AppGroupConstants.lastStartedBudgetMinutesKey)
        // Banked time is meaningless without monitoring — clear it so the
        // dashboard pill doesn't lie to a paused user.
        AppGroupConstants.sharedDefaults?.removeObject(forKey: AppGroupConstants.bankedMinutesKey)
        Task { @MainActor in
            self.bankedMinutes = 0
        }
        clearEarnedTimer()
    }

    // MARK: - Earned Timer (Calendar Time)

    /// Grants the user `minutes` of wall-clock time before shields re-apply.
    /// If a timer is already running, the new minutes stack on top of the
    /// remaining time so the user never loses earned credit.
    func startEarnedTimer(minutes: Int) {
        guard minutes > 0 else { return }
        AppGroupConstants.appendDiagnosticLog("startEarnedTimer called minutes=\(minutes)")

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

        // iOS rejects `DeviceActivitySchedule` intervals shorter than about
        // 15 minutes ("The activity's schedule is too short"). Pad the
        // schedule up to the minimum so dame's `intervalDidEnd` can still
        // fire as a backup shield-reapply mechanism, but keep the real
        // `earnedTimerEnd` at the user's actual earned duration so the UI
        // countdown and main-app expiry Timer use the correct value.
        let iosMinScheduleSeconds: TimeInterval = 15 * 60
        let scheduleEndDate = now.addingTimeInterval(max(totalSeconds, iosMinScheduleSeconds))

        AppGroupConstants.appendDiagnosticLog("startEarnedTimer: stack-remaining=\(Int(remaining))s total=\(Int(totalSeconds))s endDate=\(ISO8601DateFormatter().string(from: endDate)) scheduleEnd=\(ISO8601DateFormatter().string(from: scheduleEndDate))")

        // Do NOT call `center.stopMonitoring([earnedActivity])` here.
        // `startMonitoring` replaces any existing schedule with the same
        // activity name. Calling `stopMonitoring` first triggers dame's
        // `intervalDidEnd` callback for the old schedule, which calls
        // `applyShields()` as its expiry behavior — creating a race with
        // the `removeShields` call below. When dame's apply lands after
        // main's remove in iOS's enforcement layer, the user stays shielded
        // even though the logical state says they're in a fresh earned
        // timer. Just register the new schedule directly.

        let calendar = Calendar.current
        let startComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: now
        )
        let endComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: scheduleEndDate
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
        ShieldManager.shared.removeShields(reason: "startEarnedTimer")

        do {
            try center.startMonitoring(earnedActivity, during: schedule, events: [:])
            Self.logger.notice("earned timer registered, ends at \(endDate, privacy: .public)")
            AppGroupConstants.appendDiagnosticLog("startEarnedTimer: dame schedule registered")
        } catch {
            // UI state is already committed above; log and continue. The
            // main-app in-app Timer + refreshFromStorage on foreground will
            // re-apply shields when the wall-clock time expires, even if
            // dame never fires `intervalDidEnd` for the earned timer.
            Self.logger.error("failed to register earned timer schedule (countdown will still show, but shields may not re-apply at expiry): \(error.localizedDescription, privacy: .public)")
            AppGroupConstants.appendDiagnosticLog("startEarnedTimer: dame schedule registration FAILED: \(error.localizedDescription)")
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

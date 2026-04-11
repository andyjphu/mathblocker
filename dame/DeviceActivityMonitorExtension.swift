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
import UserNotifications
import os.log

private let bankedMinutesKey = "bankedMinutes"
private let earnedTimerEndKey = "earnedTimerEnd"
private let budgetHitDateKey = "budgetHitDate"
private let budgetHitThresholdKey = "budgetHitThreshold"
private let dailyBudgetMinutesKey = "dailyBudgetMinutes"

/// Handles two activity types:
/// 1. `mathblocker.daily` — daily budget monitoring. Fires the budget event
///    when the user has used the blocked apps for `budgetMinutes`.
/// 2. `mathblocker.earnedTimer` — calendar timer. `intervalDidEnd` fires
///    after the wall-clock duration that was earned via problem-solving.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = ManagedSettingsStore(
        named: ManagedSettingsStore.Name(rawValue: "mathblocker.session")
    )

    private let suiteName = "group.andyjphu.mathblocker"
    private let selectionKey = "activitySelection"

    private let earnedActivityName = "mathblocker.earnedTimer"
    private let budgetEventName = "mathblocker.threshold"

    private static let logger = Logger(
        subsystem: "andyjphu.mathblocker.dame",
        category: "DeviceActivityMonitor"
    )

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    /// Logs to both Apple's unified logging (visible in Xcode console and
    /// Console.app) and to a shared app-group string the main app can
    /// display in its debug view. `.notice` is used so the messages aren't
    /// filtered out by Xcode's default log level.
    private func log(_ message: String) {
        Self.logger.notice("\(message, privacy: .public)")
        let existing = defaults?.string(forKey: "extensionLog") ?? ""
        let timestamp = ISO8601DateFormatter().string(from: Date())
        defaults?.set(existing + "\n[\(timestamp)] \(message)", forKey: "extensionLog")
    }

    // MARK: - Callbacks

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        log("intervalDidStart: \(activity.rawValue)")
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        log("intervalDidEnd: \(activity.rawValue)")

        if activity.rawValue == earnedActivityName {
            // Guard against the restart race: main app may have just
            // replaced the earned-timer schedule with a fresh one, in
            // which case this `intervalDidEnd` is the old schedule
            // tearing down, not an actual expiry. If
            // `earnedTimerEnd` in the shared defaults is still in the
            // future, the user is in an active earned timer and we
            // must NOT re-apply shields (doing so would stomp on
            // main's `removeShields` call during the restart).
            let storedEnd = defaults?.double(forKey: earnedTimerEndKey) ?? 0
            let now = Date().timeIntervalSince1970
            if storedEnd > now + 5 {
                log("intervalDidEnd earnedTimer: stored end is in future (+\(Int(storedEnd - now))s), skipping applyShields (restart in progress)")
                return
            }

            // Actually expired — re-block.
            applyShields()
            store.dateAndTime.requireAutomaticDateAndTime = true
            defaults?.removeObject(forKey: earnedTimerEndKey)
            log("earned timer expired, shields applied")
        }
        // NOTE: We previously called `store.clearAllSettings()` here for
        // the daily activity, intended to reset shields at end-of-day.
        // The problem: `intervalDidEnd` *also* fires every time the
        // schedule is restarted mid-day (settings toggle, stepper change,
        // force re-register). Every restart wiped the shield before the
        // new interval's threshold event could re-apply it, producing
        // windows (visible in extensionLog) where shields were off but
        // the user was well over budget. Shields now persist across
        // intervals. The main app re-applies / removes them explicitly
        // via `ShieldManager` when the user earns time or toggles
        // monitoring; iOS won't enforce an expired shield on a new day
        // automatically, so `applyShields()` re-runs on the next
        // `eventDidReachThreshold` for the new day's interval.
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name,
                                          activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        log("eventDidReachThreshold: \(event.rawValue)")

        guard event.rawValue == budgetEventName else { return }

        // Always flag that the budget was hit today — even if we're about
        // to redeem banked time, the main app needs to know the threshold
        // fired for reconciliation logic on foreground. Record the
        // threshold value too so the main app can detect stale hits:
        // if the user later raises their budget above `budgetHitThreshold`,
        // the hit is obsolete and shields should drop.
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone = .current
        defaults?.set(fmt.string(from: Date()), forKey: budgetHitDateKey)
        let currentBudget = defaults?.integer(forKey: dailyBudgetMinutesKey) ?? 0
        defaults?.set(currentBudget, forKey: budgetHitThresholdKey)

        // Banked-minute redemption: if the user solved math while under
        // budget, we stashed the earned minutes in `bankedMinutes`. Now
        // that the budget just exhausted, redeem them as an earned timer
        // instead of applying shields.
        let banked = defaults?.integer(forKey: bankedMinutesKey) ?? 0
        if banked > 0 {
            log("budget threshold hit, redeeming \(banked) banked min instead of shielding")
            redeemBankedMinutes(banked)
            defaults?.removeObject(forKey: bankedMinutesKey)
            return
        }

        applyShields()
        store.dateAndTime.requireAutomaticDateAndTime = true
        log("budget threshold hit, shields applied")
    }

    /// Converts `minutes` of banked earned time into an active earned timer.
    /// Called from `eventDidReachThreshold` when the daily budget exhausts
    /// and there's banked time to spend first.
    private func redeemBankedMinutes(_ minutes: Int) {
        let now = Date()
        let totalSeconds = TimeInterval(minutes * 60)
        let endDate = now.addingTimeInterval(totalSeconds)

        // Write the earned-timer end (at the TRUE earned amount, not the
        // padded schedule end) so the main app's countdown UI picks it up
        // on next `refreshFromStorage` / dashboard poll.
        defaults?.set(endDate.timeIntervalSince1970, forKey: earnedTimerEndKey)

        // iOS rejects `DeviceActivitySchedule` intervals shorter than
        // about 15 minutes. Pad the schedule up to that minimum so dame's
        // `intervalDidEnd` still fires as the backup shield-reapply
        // mechanism for when the main app is backgrounded during expiry.
        let iosMinScheduleSeconds: TimeInterval = 15 * 60
        let scheduleEndDate = now.addingTimeInterval(max(totalSeconds, iosMinScheduleSeconds))

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

        let earnedActivity = DeviceActivityName(rawValue: earnedActivityName)
        let center = DeviceActivityCenter()
        do {
            try center.startMonitoring(earnedActivity, during: schedule, events: [:])
            log("redeemBankedMinutes: registered schedule until \(ISO8601DateFormatter().string(from: scheduleEndDate)), real end \(ISO8601DateFormatter().string(from: endDate))")
        } catch {
            log("redeemBankedMinutes: failed to register earned timer (main app will handle expiry): \(error.localizedDescription)")
        }
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name,
                                                  activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
        log("eventWillReachThresholdWarning: \(event.rawValue)")

        guard event.rawValue == budgetEventName else { return }

        let lastWarning = defaults?.double(forKey: "lastWarningTimestamp") ?? 0
        let now = Date().timeIntervalSince1970
        guard now - lastWarning > 1800 else {
            log("warning notification skipped (recently sent)")
            return
        }
        defaults?.set(now, forKey: "lastWarningTimestamp")

        sendWarningNotification()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
    }

    // MARK: - Notifications

    private func sendWarningNotification() {
        let content = UNMutableNotificationContent()
        content.title = "5 minutes left"
        content.body = "your blocked apps are about to be locked. open MathBlocker to earn more time."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "threshold-warning",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Shields

    private func applyShields() {
        guard let defaults,
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

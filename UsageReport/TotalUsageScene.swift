//
//  TotalUsageScene.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import ExtensionKit
import ManagedSettings
import SwiftUI

extension DeviceActivityReport.Context {
    static let totalUsage = Self("totalUsage")
    static let budgetOverage = Self("budgetOverage")
    static let budgetRemaining = Self("budgetRemaining")
}

/// Computes today's total usage across the monitored apps and compares it to
/// the user's daily budget (read from the shared app group). Used by both
/// `BudgetOverageScene` and `BudgetRemainingScene`.
private func computeBudgetStatus(data: DeviceActivityResults<DeviceActivityData>) async -> BudgetStatus {
    var totalDuration: TimeInterval = 0
    for await activityData in data {
        for await segment in activityData.activitySegments {
            for await category in segment.categories {
                for await appActivity in category.applications {
                    totalDuration += appActivity.totalActivityDuration
                }
            }
        }
    }
    // DAR extensions can read app-group UserDefaults (just not write).
    let defaults = UserDefaults(suiteName: "group.andyjphu.mathblocker")
    let budgetMinutes = defaults?.integer(forKey: "dailyBudgetMinutes") ?? 30
    let budgetSeconds = TimeInterval(budgetMinutes * 60)
    return BudgetStatus(usage: totalDuration, budget: budgetSeconds)
}

/// Renders a tiny one-line overage summary for the hero when shields are up.
struct BudgetOverageScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .budgetOverage
    let content: (BudgetStatus) -> BudgetOverageView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> BudgetStatus {
        await computeBudgetStatus(data: data)
    }
}

/// Renders the large "X min / of free app time today" hero number, computed
/// as `budget - usage` so it decreases as the user consumes their budget.
struct BudgetRemainingScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .budgetRemaining
    let content: (BudgetStatus) -> BudgetRemainingView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> BudgetStatus {
        await computeBudgetStatus(data: data)
    }
}

struct TotalUsageScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalUsage
    let content: (UsageReport) -> UsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> UsageReport {
        var totalDuration: TimeInterval = 0
        var totalPickups = 0
        var appDurations: [String: (duration: TimeInterval, pickups: Int)] = [:]
        var hourlyDurations: [Int: TimeInterval] = [:]

        for await activityData in data {
            for await segment in activityData.activitySegments {
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)

                // Sum from app-level data only (segment.totalActivityDuration includes all apps, not just filtered ones)
                for await category in segment.categories {
                    for await appActivity in category.applications {
                        let name = appActivity.application.localizedDisplayName ?? "unknown"
                        let dur = appActivity.totalActivityDuration
                        let picks = appActivity.numberOfPickups

                        totalDuration += dur
                        totalPickups += picks
                        hourlyDurations[hour, default: 0] += dur

                        let existing = appDurations[name] ?? (0, 0)
                        appDurations[name] = (existing.duration + dur, existing.pickups + picks)
                    }
                }
            }
        }

        // Top apps sorted by duration
        let topApps = appDurations
            .map { AppUsage(name: $0.key, duration: $0.value.duration, pickups: $0.value.pickups) }
            .sorted { $0.duration > $1.duration }
            .prefix(5)

        // Hourly buckets (0-23)
        let hourlyData = (0...23).map { hour in
            HourlyBucket(hour: hour, duration: hourlyDurations[hour] ?? 0)
        }

        return UsageReport(
            totalDuration: totalDuration,
            topApps: Array(topApps),
            hourlyData: hourlyData,
            totalPickups: totalPickups
        )
    }
}

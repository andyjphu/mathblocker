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
                totalDuration += segment.totalActivityDuration

                // Bucket by hour
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)
                hourlyDurations[hour, default: 0] += segment.totalActivityDuration

                // Per-app breakdown (segment → categories → applications)
                for await category in segment.categories {
                    for await appActivity in category.applications {
                        let name = appActivity.application.localizedDisplayName ?? "unknown"
                        let existing = appDurations[name] ?? (0, 0)
                        appDurations[name] = (
                            existing.duration + appActivity.totalActivityDuration,
                            existing.pickups + appActivity.numberOfPickups
                        )
                        totalPickups += appActivity.numberOfPickups
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

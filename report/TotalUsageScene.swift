//
//  TotalUsageScene.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import SwiftUI
import ExtensionKit

struct TotalUsageScene: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .init(rawValue: "totalUsage")
    let content: (String) -> UsageReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> String {
        var totalDuration: TimeInterval = 0

        for await activityData in data {
            for await segment in activityData.activitySegments {
                totalDuration += segment.totalActivityDuration
            }
        }

        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

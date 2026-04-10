//
//  ReportModels.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// Lightweight data passed from scene → view (keeps memory low).
struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let duration: TimeInterval
    let pickups: Int
}

struct HourlyBucket: Identifiable {
    let id = UUID()
    let hour: Int
    let duration: TimeInterval
}

struct UsageReport {
    let totalDuration: TimeInterval
    let topApps: [AppUsage]
    let hourlyData: [HourlyBucket]
    let totalPickups: Int
}

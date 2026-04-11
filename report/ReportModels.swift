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

/// Usage-vs-budget summary computed inside the DAR extension (the only
/// process that can read actual screen time). Used by the dashboard hero to
/// show either how much free time is left (state 1) or how far over the
/// budget the user is (state 3).
struct BudgetStatus {
    let usage: TimeInterval
    let budget: TimeInterval
    /// `max(0, usage - budget)`. Zero means still under budget.
    var overage: TimeInterval { max(0, usage - budget) }
    /// `max(0, budget - usage)`. Zero means budget exhausted.
    var remaining: TimeInterval { max(0, budget - usage) }
}

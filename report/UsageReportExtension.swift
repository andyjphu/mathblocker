//
//  UsageReportExtension.swift
//  report
//
//  Created by Andy Phu on 4/9/26.
//

import DeviceActivity
import SwiftUI
import ExtensionKit

@main
struct UsageReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalUsageScene { report in
            UsageReportView(report: report)
        }
        BudgetOverageScene { status in
            BudgetOverageView(data: status)
        }
        BudgetRemainingScene { status in
            BudgetRemainingView(data: status)
        }
    }
}

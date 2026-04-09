//
//  AppGroupConstants.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

enum AppGroupConstants {
    static let suiteName = "group.andyjphu.mathblocker"
    static let selectionKey = "activitySelection"
    static let budgetMinutesKey = "dailyBudgetMinutes"
    static let minutesPerCorrectKey = "minutesPerCorrect"
    static let shieldStoreName = "mathblocker.session"
    static let activityName = "mathblocker.daily"
    static let thresholdEventName = "mathblocker.threshold"
    static let urlScheme = "mathblocker"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }
}

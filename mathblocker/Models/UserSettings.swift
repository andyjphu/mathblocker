//
//  UserSettings.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation
import SwiftData

/// User-configurable preferences — daily time budget, difficulty,
/// questions per session, and monitoring state. Stored via SwiftData.
@Model
final class UserSettings {
    var dailyTimeBudgetMinutes: Int
    var minutesPerCorrectAnswer: Int
    var questionsPerSession: Int
    var difficultyLevel: Int // 1-5
    var isMonitoringEnabled: Bool
    var selectedSource: String // "all", "aqua_rat", "hendrycks_math", "mmlu"

    init(dailyTimeBudgetMinutes: Int = 30, minutesPerCorrectAnswer: Int = 2, questionsPerSession: Int = 5, difficultyLevel: Int = 1, isMonitoringEnabled: Bool = false, selectedSource: String = "hendrycks_math") {
        self.dailyTimeBudgetMinutes = dailyTimeBudgetMinutes
        self.minutesPerCorrectAnswer = minutesPerCorrectAnswer
        self.questionsPerSession = questionsPerSession
        self.difficultyLevel = difficultyLevel
        self.isMonitoringEnabled = isMonitoringEnabled
        self.selectedSource = selectedSource
    }
}

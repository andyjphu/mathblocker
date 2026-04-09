//
//  DailyStats.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation
import SwiftData

/// Aggregated stats for a single calendar day — questions attempted,
/// correct answers, and screen time earned/used.
@Model
final class DailyStats {
    var date: Date
    var questionsAttempted: Int
    var questionsCorrect: Int
    var minutesEarned: Int
    var minutesUsed: Int

    var accuracy: Double {
        guard questionsAttempted > 0 else { return 0 }
        return Double(questionsCorrect) / Double(questionsAttempted)
    }

    init(date: Date = .now, questionsAttempted: Int = 0, questionsCorrect: Int = 0, minutesEarned: Int = 0, minutesUsed: Int = 0) {
        self.date = Calendar.current.startOfDay(for: date)
        self.questionsAttempted = questionsAttempted
        self.questionsCorrect = questionsCorrect
        self.minutesEarned = minutesEarned
        self.minutesUsed = minutesUsed
    }
}

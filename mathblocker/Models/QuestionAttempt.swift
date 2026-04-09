//
//  QuestionAttempt.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation
import SwiftData

@Model
final class QuestionAttempt {
    var question: String
    var correctAnswer: String
    var userAnswer: String
    var isCorrect: Bool
    var difficulty: Int // 1-5 tier
    var topic: String
    var timeSpentSeconds: Double
    var timestamp: Date

    init(question: String, correctAnswer: String, userAnswer: String, isCorrect: Bool, difficulty: Int, topic: String, timeSpentSeconds: Double, timestamp: Date = .now) {
        self.question = question
        self.correctAnswer = correctAnswer
        self.userAnswer = userAnswer
        self.isCorrect = isCorrect
        self.difficulty = difficulty
        self.topic = topic
        self.timeSpentSeconds = timeSpentSeconds
        self.timestamp = timestamp
    }
}

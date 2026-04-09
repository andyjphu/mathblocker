//
//  MathQuestion.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// A single math question with multiple-choice answers.
/// Used by both the bundled question bank and the procedural generator.
nonisolated struct MathQuestion: Identifiable, Sendable {
    let id = UUID()
    let text: String
    let choices: [String]
    let correctAnswerIndex: Int
    let difficulty: Int
    let topic: String
    var rationale: String?
    var globalIndex: Int?

    var correctAnswer: String {
        choices[correctAnswerIndex]
    }
}

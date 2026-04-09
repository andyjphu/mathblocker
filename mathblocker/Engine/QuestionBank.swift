//
//  QuestionBank.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// JSON-decodable question from the bundled questions.json dataset.
struct BundledQuestion: Codable, Sendable {
    let question: String
    let choices: [String]
    let correctAnswerIndex: Int
    let difficulty: Int
    let topic: String
    let source: String
}

/// Thread-safe store of bundled math questions loaded from questions.json.
/// Pre-indexes by difficulty for fast random selection.
actor QuestionBank {
    static let shared = QuestionBank()

    private var questions: [BundledQuestion] = []
    private var byDifficulty: [Int: [BundledQuestion]] = [:]
    private var loaded = false

    func load() {
        guard !loaded else { return }
        guard let url = Bundle.main.url(forResource: "questions", withExtension: "json") else {
            print("QuestionBank: questions.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            questions = try JSONDecoder().decode([BundledQuestion].self, from: data)
            byDifficulty = Dictionary(grouping: questions, by: \.difficulty)
            loaded = true
            print("QuestionBank: loaded \(questions.count) questions")
        } catch {
            print("QuestionBank: failed to load: \(error)")
        }
    }

    var isLoaded: Bool { loaded }
    var totalCount: Int { questions.count }

    func randomQuestions(difficulty: Int, count: Int) -> [MathQuestion] {
        let pool = byDifficulty[difficulty] ?? byDifficulty[2] ?? []
        guard !pool.isEmpty else { return [] }

        let selected = pool.shuffled().prefix(count)
        return selected.map { q in
            let globalIdx = questions.firstIndex(where: { $0.question == q.question })
            return MathQuestion(
                text: q.question,
                choices: q.choices,
                correctAnswerIndex: q.correctAnswerIndex,
                difficulty: q.difficulty,
                topic: q.topic,
                globalIndex: globalIdx
            )
        }
    }

    func countByDifficulty() -> [Int: Int] {
        byDifficulty.mapValues(\.count)
    }
}

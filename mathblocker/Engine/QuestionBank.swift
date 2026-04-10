//
//  QuestionBank.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

/// JSON-decodable question from bundled or downloaded datasets.
struct BundledQuestion: Codable, Sendable {
    let question: String
    let choices: [String]
    let correctAnswerIndex: Int
    let difficulty: Int
    let topic: String
    let source: String
}

/// Thread-safe store of math questions from bundled + downloaded packs.
/// Loads the default bundle on startup, then merges any downloaded packs.
actor QuestionBank {
    static let shared = QuestionBank()

    private var questions: [BundledQuestion] = []
    private var bySource: [String: [BundledQuestion]] = [:]
    private var loaded = false

    /// Load bundled questions and any downloaded packs.
    func load() {
        guard !loaded else { return }

        // 1. Load bundled default
        if let url = Bundle.main.url(forResource: "questions", withExtension: "json") {
            do {
                let data = try Data(contentsOf: url)
                let bundled = try JSONDecoder().decode([BundledQuestion].self, from: data)
                questions.append(contentsOf: bundled)
                print("QuestionBank: loaded \(bundled.count) bundled questions")
            } catch {
                print("QuestionBank: failed to load bundle: \(error)")
            }
        }

        // 2. Load downloaded packs
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let packsDir = docs.appendingPathComponent("QuestionPacks", isDirectory: true)
        if let files = try? FileManager.default.contentsOfDirectory(at: packsDir, includingPropertiesForKeys: nil) {
            for file in files where file.pathExtension == "json" {
                do {
                    let data = try Data(contentsOf: file)
                    let packQuestions = try JSONDecoder().decode([BundledQuestion].self, from: data)
                    questions.append(contentsOf: packQuestions)
                    print("QuestionBank: loaded \(packQuestions.count) from \(file.lastPathComponent)")
                } catch {
                    print("QuestionBank: failed to load \(file.lastPathComponent): \(error)")
                }
            }
        }

        bySource = Dictionary(grouping: questions, by: \.source)
        loaded = true
        // Cache source list for sync access from UI
        UserDefaults.standard.set(Array(bySource.keys).sorted(), forKey: "questionBankSources")
        print("QuestionBank: \(questions.count) total questions, \(bySource.keys.count) sources")
    }

    /// Force reload (after downloading a new pack).
    func reload() {
        loaded = false
        questions = []
        bySource = [:]
        load()
    }

    var isLoaded: Bool { loaded }
    var totalCount: Int { questions.count }
    var availableSources: [String] { Array(bySource.keys).sorted() }

    /// Non-isolated access for SwiftUI Picker (reads cached value).
    nonisolated var availableSourcesSync: [String] {
        let defaults = UserDefaults.standard
        return defaults.stringArray(forKey: "questionBankSources") ?? ["hendrycks_math"]
    }

    func randomQuestions(difficulty: Int, count: Int, source: String = "all") -> [MathQuestion] {
        var pool: [BundledQuestion]

        if source == "all" {
            pool = questions
        } else {
            pool = bySource[source] ?? []
        }

        // Filter by difficulty if there are enough questions
        let diffFiltered = pool.filter { $0.difficulty == difficulty }
        if diffFiltered.count >= count {
            pool = diffFiltered
        }

        guard !pool.isEmpty else { return [] }

        let selected = pool.shuffled().prefix(count)
        return selected.map { q in
            MathQuestion(
                text: q.question,
                choices: q.choices,
                correctAnswerIndex: q.correctAnswerIndex,
                difficulty: q.difficulty,
                topic: q.topic,
                globalIndex: nil
            )
        }
    }

    func countBySource() -> [String: Int] {
        bySource.mapValues(\.count)
    }
}

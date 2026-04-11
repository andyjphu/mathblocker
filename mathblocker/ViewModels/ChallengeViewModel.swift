//
//  ChallengeViewModel.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

/// Manages state for a math challenge session — question progression,
/// scoring, timing, and persistence of results to SwiftData.
@Observable
class ChallengeViewModel {
    var questions: [MathQuestion] = []
    var currentIndex = 0
    var selectedAnswer: Int?
    var results: [Bool] = []
    var sessionComplete = false
    var elapsedSeconds: Double = 0
    var score = 0
    var minutesPerCorrect = 2
    var currentRationale: String?

    /// Total screen time earned this session based on correct answers.
    var minutesEarned: Int { score * minutesPerCorrect }

    private var timer: Timer?
    private var questionStartTime: Date = .now

    var currentQuestion: MathQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var formattedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    deinit {
        timer?.invalidate()
    }

    /// Starts a new session by loading questions from the bank (with procedural fallback)
    /// and resetting all state.
    func startSession(difficulty: Int = 1, count: Int = 5, source: String = "all") {
        let task = Task {
            let bank = QuestionBank.shared
            await bank.load()
            return await bank.randomQuestions(difficulty: difficulty, count: count, source: source)
        }
        // Procedural fallback while bank loads
        questions = QuestionGenerator.generate(difficulty: difficulty, count: count)
        Task { @MainActor in
            let bankQuestions = await task.value
            if !bankQuestions.isEmpty && self.currentIndex == 0 && self.selectedAnswer == nil {
                self.questions = bankQuestions
            }
        }
        currentIndex = 0
        selectedAnswer = nil
        results = []
        sessionComplete = false
        score = 0
        elapsedSeconds = 0
        questionStartTime = .now

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    /// Returns the visual state for a given choice index based on the current answer.
    func choiceState(for index: Int) -> ChoiceState {
        guard let selected = selectedAnswer, let question = currentQuestion else { return .neutral }
        if index == question.correctAnswerIndex { return .correct }
        if index == selected { return .incorrect }
        return .dimmed
    }

    /// Records the user's answer, updates score, triggers haptics,
    /// and loads the rationale asynchronously.
    func selectAnswer(_ index: Int) {
        guard selectedAnswer == nil, let question = currentQuestion else { return }
        selectedAnswer = index
        let correct = index == question.correctAnswerIndex
        results.append(correct)
        if correct {
            score += 1
            Haptics.correct()
        } else {
            Haptics.incorrect()
        }

        if let globalIdx = question.globalIndex {
            Task { @MainActor in
                self.currentRationale = await RationaleBank.shared.rationale(forIndex: globalIdx)
            }
        }
    }

    /// Persists the current question attempt and advances to the next question,
    /// or completes the session if all questions are answered.
    func advance(modelContext: ModelContext) {
        // Re-entry guard: a rapid double-tap on "next" would otherwise record a
        // garbage attempt using `selectedAnswer ?? 0` and `results.last` from the
        // previous question, and stack up SwiftData inserts that stall the UI.
        // The button is only visible when `selectedAnswer != nil`, so the first
        // tap's clearing of it makes subsequent taps a no-op.
        guard selectedAnswer != nil, !sessionComplete, let question = currentQuestion else { return }

        let timeSpent = Date.now.timeIntervalSince(questionStartTime)
        let attempt = QuestionAttempt(
            question: question.text,
            correctAnswer: question.correctAnswer,
            userAnswer: question.choices[selectedAnswer ?? 0],
            isCorrect: results.last ?? false,
            difficulty: question.difficulty,
            topic: question.topic,
            timeSpentSeconds: timeSpent
        )
        modelContext.insert(attempt)

        selectedAnswer = nil
        currentRationale = nil
        currentIndex += 1
        questionStartTime = .now

        if currentIndex >= questions.count {
            sessionComplete = true
            timer?.invalidate()
            recordDailyStats(modelContext: modelContext)
            redeemEarnedMinutes(modelContext: modelContext)
        }
    }

    /// Records whether the most recent `redeemEarnedMinutes` call banked
    /// the earned time (user was under budget and not in an active earned
    /// timer) vs. redeemed it immediately. Used by the session-complete
    /// view to show the right messaging.
    var lastRedemptionWasBanked: Bool = false

    /// After a session, either starts a wall-clock earned timer immediately
    /// (when the user is already blocked or in an active earned timer) or
    /// banks the minutes for later redemption when the budget exhausts.
    ///
    /// Banking avoids the failure mode where a user solves math while under
    /// budget and watches the earned time tick away while they're still
    /// consuming their free daily budget — previously those minutes fell
    /// on the floor.
    private func redeemEarnedMinutes(modelContext: ModelContext) {
        guard minutesEarned > 0 else { return }

        let shieldsUp = ShieldManager.shared.shieldsAreActive
        let timerActive = MonitoringManager.shared.earnedTimerEnd != nil
        let shouldRedeemNow = shieldsUp || timerActive

        AppGroupConstants.appendDiagnosticLog(
            "ChallengeViewModel.redeemEarnedMinutes: minutesEarned=\(minutesEarned) score=\(score)/\(questions.count) shieldsUp=\(shieldsUp) timerActive=\(timerActive) → \(shouldRedeemNow ? "redeem" : "bank")"
        )

        if shouldRedeemNow {
            lastRedemptionWasBanked = false
            MonitoringManager.shared.startEarnedTimer(minutes: minutesEarned)
        } else {
            lastRedemptionWasBanked = true
            MonitoringManager.shared.bankMinutes(minutesEarned)
        }
    }

    private func recordDailyStats(modelContext: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyStats>(
            predicate: #Predicate { $0.date == today }
        )

        let existing = try? modelContext.fetch(descriptor).first

        if let stats = existing {
            stats.questionsAttempted += questions.count
            stats.questionsCorrect += score
            stats.minutesEarned += minutesEarned
        } else {
            let stats = DailyStats(
                date: .now,
                questionsAttempted: questions.count,
                questionsCorrect: score,
                minutesEarned: minutesEarned
            )
            modelContext.insert(stats)
        }
    }
}

/// Visual state of a multiple-choice answer button.
enum ChoiceState {
    case neutral, correct, incorrect, dimmed
}

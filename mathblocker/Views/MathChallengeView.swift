//
//  MathChallengeView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftData

struct MathChallengeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settings: [UserSettings]
    @State private var viewModel = ChallengeViewModel()

    /// If launched from shield unlock, complete this to remove shields
    var onUnlock: ((Int) -> Void)?

    private var currentSettings: UserSettings? { settings.first }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if viewModel.sessionComplete {
                    sessionCompleteView
                } else {
                    questionView
                }
            }
            .navigationTitle("Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.sessionComplete {
                    ToolbarItem(placement: .principal) {
                        progressIndicator
                    }
                }
            }
        }
        .onAppear {
            if viewModel.questions.isEmpty {
                let diff = currentSettings?.difficultyLevel ?? 1
                let count = currentSettings?.questionsPerSession ?? 5
                viewModel.minutesPerCorrect = currentSettings?.minutesPerCorrectAnswer ?? 2
                viewModel.startSession(difficulty: diff, count: count)
            }
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            Spacer()

            // Topic pill
            Text(viewModel.currentQuestion?.topic ?? "")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 16)

            // Question text
            Text(viewModel.currentQuestion?.text ?? "")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)

            // Answer choices
            VStack(spacing: 12) {
                ForEach(Array((viewModel.currentQuestion?.choices ?? []).enumerated()), id: \.offset) { index, choice in
                    ChoiceButton(
                        label: choiceLetter(index),
                        text: choice,
                        state: viewModel.choiceState(for: index)
                    ) {
                        withAnimation(.spring(response: 0.3)) {
                            viewModel.selectAnswer(index)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .disabled(viewModel.selectedAnswer != nil)

            // Rationale + Continue
            if viewModel.selectedAnswer != nil {
                VStack(spacing: 12) {
                    if let rationale = viewModel.currentRationale, !rationale.isEmpty {
                        ScrollView {
                            Text(rationale)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                        .frame(maxHeight: 120)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 24)
                    }

                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.advance(modelContext: modelContext)
                        }
                    } label: {
                        Text(viewModel.currentIndex + 1 >= viewModel.questions.count ? "Finish" : "Next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 24)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.top, 12)
            }

            Spacer()

            // Timer
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                Text(viewModel.formattedTime)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Session Complete

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: viewModel.score == viewModel.questions.count ? "star.fill" : "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(viewModel.score == viewModel.questions.count ? .yellow : .green)
                .symbolEffect(.bounce, value: viewModel.sessionComplete)

            Text(viewModel.score == viewModel.questions.count ? "Perfect!" : "Session Complete")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("\(viewModel.score)/\(viewModel.questions.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            let earned = viewModel.minutesEarned
            if earned > 0 {
                Text("+\(earned) minutes earned")
                    .font(.headline)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(spacing: 12) {
                if onUnlock != nil && earned > 0 {
                    Button {
                        onUnlock?(earned)
                    } label: {
                        Text("Unlock Apps (\(earned) min)")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button {
                    withAnimation {
                        let diff = currentSettings?.difficultyLevel ?? 1
                        let count = currentSettings?.questionsPerSession ?? 5
                        viewModel.startSession(difficulty: diff, count: count)
                    }
                } label: {
                    Text("New Session")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Progress Indicator

    private var progressIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<viewModel.questions.count, id: \.self) { i in
                Circle()
                    .fill(dotColor(for: i))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func dotColor(for index: Int) -> Color {
        if index < viewModel.currentIndex {
            return viewModel.results[index] == true ? .green : .red
        } else if index == viewModel.currentIndex {
            return .blue
        }
        return .gray.opacity(0.3)
    }

    private func choiceLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "\(index + 1)"
    }
}

// MARK: - Choice Button

struct ChoiceButton: View {
    let label: String
    let text: String
    let state: ChoiceState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .frame(width: 32, height: 32)
                    .background(backgroundForLabel)
                    .foregroundStyle(foregroundForLabel)
                    .clipShape(Circle())

                Text(text)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(foregroundForText)

                Spacer()

                if state == .correct {
                    Image(systemName: "checkmark")
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else if state == .incorrect {
                    Image(systemName: "xmark")
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: state == .neutral ? 0 : 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        switch state {
        case .neutral: .init(.secondarySystemGroupedBackground)
        case .correct: .green.opacity(0.1)
        case .incorrect: .red.opacity(0.1)
        case .dimmed: .init(.secondarySystemGroupedBackground).opacity(0.5)
        }
    }

    private var borderColor: Color {
        switch state {
        case .correct: .green
        case .incorrect: .red
        default: .clear
        }
    }

    private var backgroundForLabel: Color {
        switch state {
        case .correct: .green
        case .incorrect: .red
        case .neutral: .blue.opacity(0.1)
        case .dimmed: .gray.opacity(0.1)
        }
    }

    private var foregroundForLabel: Color {
        switch state {
        case .correct, .incorrect: .white
        case .neutral: .blue
        case .dimmed: .gray
        }
    }

    private var foregroundForText: Color {
        state == .dimmed ? .gray : .primary
    }
}

enum ChoiceState {
    case neutral, correct, incorrect, dimmed
}

// MARK: - View Model

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

    var minutesEarned: Int { score * minutesPerCorrect }

    private var timer: Timer?
    private var questionStartTime: Date = .now
    private var questionRationales: [Int: String] = [:]

    var currentQuestion: MathQuestion? {
        guard currentIndex < questions.count else { return nil }
        return questions[currentIndex]
    }

    var formattedTime: String {
        let mins = Int(elapsedSeconds) / 60
        let secs = Int(elapsedSeconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    func startSession(difficulty: Int = 1, count: Int = 5) {
        // Try bundled question bank first, fall back to procedural
        let task = Task {
            let bank = QuestionBank.shared
            await bank.load()
            let bankQuestions = await bank.randomQuestions(difficulty: difficulty, count: count)
            return bankQuestions
        }
        // Use procedural as immediate fallback, replace if bank loads
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

    func choiceState(for index: Int) -> ChoiceState {
        guard let selected = selectedAnswer, let question = currentQuestion else { return .neutral }
        if index == question.correctAnswerIndex { return .correct }
        if index == selected { return .incorrect }
        return .dimmed
    }

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

        // Load rationale if available
        if let globalIdx = question.globalIndex {
            Task { @MainActor in
                let bank = RationaleBank.shared
                await bank.load()
                self.currentRationale = await bank.rationale(forIndex: globalIdx)
            }
        }
    }

    func advance(modelContext: ModelContext) {
        guard let question = currentQuestion else { return }

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

#Preview {
    MathChallengeView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}

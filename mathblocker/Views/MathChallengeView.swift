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
            Group {
                if viewModel.sessionComplete {
                    sessionCompleteView
                } else {
                    questionView
                }
            }
            .fontDesign(.serif)
            .background { FrostedBackground(image: "dense-fern") }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    if !viewModel.sessionComplete {
                        progressIndicator
                    } else {
                        Text("Practice")
                            .font(Theme.titleFont(size: 20))
                    }
                }
            }
        }
        .onAppear {
            if viewModel.questions.isEmpty {
                let diff = currentSettings?.difficultyLevel ?? 1
                let count = currentSettings?.questionsPerSession ?? 5
                viewModel.minutesPerCorrect = currentSettings?.minutesPerCorrectAnswer ?? 2
                let source = currentSettings?.selectedSource ?? "hendrycks_math"
                viewModel.startSession(difficulty: diff, count: count, source: source)
            }
        }
    }

    // MARK: - Question View

    private var questionView: some View {
        VStack(spacing: 0) {
            // Scrollable content
            ScrollView {
                VStack(spacing: 0) {
                    // Topic pill
                    Text(viewModel.currentQuestion?.topic ?? "")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cardBackground)
                        .clipShape(Capsule())
                        .cardShadow()
                        .padding(.bottom, 16)
                        .padding(.top, 16)

                    // Question text
                    MathText(text: viewModel.currentQuestion?.text ?? "")
                        .font(.body)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .cardShadow()
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)

                    // Answer choices
                    VStack(spacing: 12) {
                        ForEach(Array((viewModel.currentQuestion?.choices ?? []).enumerated()), id: \.offset) { index, choice in
                            ChoiceButton(
                                label: choiceLetter(index),
                                text: choice,
                                state: viewModel.choiceState(for: index)
                            ) {
                                viewModel.selectAnswer(index)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .disabled(viewModel.selectedAnswer != nil)

                    // Rationale (inline, scrolls with content)
                    if viewModel.selectedAnswer != nil,
                       let rationale = viewModel.currentRationale, !rationale.isEmpty {
                        Text(rationale)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .cardShadow()
                            .padding(.horizontal, 24)
                            .padding(.top, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(.bottom, 24)
            }

            // Pinned bottom bar
            VStack(spacing: 10) {
                if viewModel.selectedAnswer != nil {
                    Button {
                        withAnimation(.spring(response: 0.4)) {
                            viewModel.advance(modelContext: modelContext)
                        }
                    } label: {
                        Text(viewModel.currentIndex + 1 >= viewModel.questions.count ? "finish" : "next")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                HStack {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    Text(viewModel.formattedTime)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
            .padding(.top, 8)
            .background(Theme.cardBackground, ignoresSafeAreaEdges: .bottom)
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

            Text(viewModel.score == viewModel.questions.count ? "nice, perfect" : "done")
                .font(Theme.titleFont(size: 34))

            Text("\(viewModel.score)/\(viewModel.questions.count) correct")
                .font(.title3)
                .foregroundStyle(.secondary)

            let earned = viewModel.minutesEarned
            if earned > 0 {
                Text("+\(earned) min earned")
                    .font(.headline)
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.accent.opacity(0.1))
                    .clipShape(Capsule())
            }

            Spacer()

            VStack(spacing: 12) {
                if onUnlock != nil && earned > 0 {
                    Button {
                        onUnlock?(earned)
                    } label: {
                        Text("unlock apps (\(earned) min)")
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
                        let source = currentSettings?.selectedSource ?? "hendrycks_math"
                viewModel.startSession(difficulty: diff, count: count, source: source)
                    }
                } label: {
                    Text("go again")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.accent)
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
            return .accent
        }
        return .gray.opacity(0.3)
    }

    private func choiceLetter(_ index: Int) -> String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        return index < letters.count ? letters[index] : "\(index + 1)"
    }
}

#Preview {
    MathChallengeView()
        .modelContainer(for: [QuestionAttempt.self, DailyStats.self, UserSettings.self], inMemory: true)
}

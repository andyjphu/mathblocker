//
//  ChoiceButton.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// A multiple-choice answer button with letter label, answer text,
/// and correct/incorrect/dimmed visual states.
struct ChoiceButton: View {
    let label: String
    let text: String
    let state: ChoiceState
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.bold)
                .frame(width: 32, height: 32)
                .background(backgroundForLabel)
                .foregroundStyle(foregroundForLabel)
                .clipShape(Circle())

            MathText(text: text)
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
        .cardShadow()
        .contentShape(Rectangle())
        .onTapGesture {
            action()
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .neutral: Theme.cardBackground
        case .correct: Color(red: 0.92, green: 0.98, blue: 0.92, opacity: 0.9)
        case .incorrect: Color(red: 0.98, green: 0.92, blue: 0.92, opacity: 0.9)
        case .dimmed: Color(white: 0.98, opacity: 0.5)
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
        case .neutral: .black.opacity(0.08)
        case .dimmed: .black.opacity(0.04)
        }
    }

    private var foregroundForLabel: Color {
        switch state {
        case .correct, .incorrect: .white
        case .neutral: .primary
        case .dimmed: .secondary
        }
    }

    private var foregroundForText: Color {
        state == .dimmed ? .secondary : .primary
    }
}

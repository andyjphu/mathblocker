//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders text that may contain LaTeX math expressions.
/// Only routes through LaTeXSwiftUI when there's actual LaTeX content,
/// otherwise uses plain Text to avoid parser failures and overhead.
struct MathText: View {
    let text: String

    private var hasLaTeX: Bool {
        text.contains("$") ||
        text.contains("\\[") ||
        text.contains("\\(") ||
        containsLaTeXCommand(text)
    }

    var body: some View {
        if hasLaTeX {
            LaTeX(processedText)
                .fontDesign(.serif)
        } else {
            Text(text)
        }
    }

    private var processedText: String {
        var t = text

        // Fix unbalanced $ count (rare data issue)
        let dollarCount = t.filter { $0 == "$" }.count
        if dollarCount % 2 != 0 {
            t = t.replacingOccurrences(of: "$", with: "")
        }

        // Bare LaTeX commands with no delimiters: wrap them
        let hasDelimiters = t.contains("$") || t.contains("\\[") || t.contains("\\(")
        if !hasDelimiters && containsLaTeXCommand(t) {
            return "$\(t)$"
        }

        return t
    }

    private func containsLaTeXCommand(_ text: String) -> Bool {
        let commands = [
            "\\frac", "\\sqrt", "\\cdot", "\\times", "\\div",
            "\\le", "\\ge", "\\neq", "\\approx", "\\infty",
            "\\sum", "\\prod", "\\int", "\\lim", "\\log",
            "\\sin", "\\cos", "\\tan", "\\binom", "\\overline",
            "\\pi", "\\theta", "\\alpha", "\\beta"
        ]
        return commands.contains { text.contains($0) }
    }
}

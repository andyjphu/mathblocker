//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders text that may contain LaTeX math expressions.
/// Handles three cases:
/// 1. Properly delimited text (`$...$`, `\[...\]`, `\(...\)`) — pass through
/// 2. Bare LaTeX commands with no delimiters — wrap in `$...$`
/// 3. Plain prose — pass through
struct MathText: View {
    let text: String

    var body: some View {
        LaTeX(processedText)
            .fontDesign(.serif)
    }

    private var processedText: String {
        var t = text

        // Fix unbalanced $ count (rare data issue)
        let dollarCount = t.filter { $0 == "$" }.count
        if dollarCount % 2 != 0 {
            t = t.replacingOccurrences(of: "$", with: "")
        }

        // If the string has bare LaTeX commands but no delimiters at all,
        // wrap the whole thing so LaTeXSwiftUI parses it as math.
        let hasDelimiters = t.contains("$") || t.contains("\\[") || t.contains("\\(")
        let hasBareLaTeX = containsLaTeXCommand(t)

        if hasBareLaTeX && !hasDelimiters {
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

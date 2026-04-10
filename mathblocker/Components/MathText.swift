//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders text that may contain LaTeX math expressions.
/// Handles all common LaTeX patterns: `$...$`, `$$...$$`, `\[...\]`,
/// `\(...\)`, and bare LaTeX commands like `\frac`, `\sqrt`.
/// Falls back to plain Text when no LaTeX is detected.
struct MathText: View {
    let text: String

    private var hasLaTeX: Bool {
        text.contains("$") ||
        text.contains("\\[") ||
        text.contains("\\(") ||
        text.contains("\\frac") ||
        text.contains("\\sqrt") ||
        text.contains("\\cdot") ||
        text.contains("\\text") ||
        text.contains("\\pi") ||
        text.contains("\\times") ||
        text.contains("\\begin") ||
        text.contains("\\le") ||
        text.contains("\\ge") ||
        text.contains("\\neq")
    }

    /// Ensures all LaTeX content is properly delimited for LaTeXSwiftUI.
    private var processedText: String {
        var t = text

        // If no delimiters at all but has LaTeX commands, wrap the whole thing
        if !t.contains("$") && !t.contains("\\[") && !t.contains("\\(") {
            return "$\(t)$"
        }

        // Fix bare LaTeX commands that appear between $...$ blocks.
        // Split by $ and check even-indexed parts (outside math mode).
        // If they contain LaTeX commands, wrap them.
        let parts = t.components(separatedBy: "$")
        if parts.count > 1 {
            var result: [String] = []
            for (i, part) in parts.enumerated() {
                if i % 2 == 0 {
                    // Outside math mode — check for orphaned LaTeX
                    if containsLaTeXCommand(part) {
                        // Wrap the LaTeX portion in $ delimiters
                        result.append(wrapOrphanedLaTeX(in: part))
                    } else {
                        result.append(part)
                    }
                } else {
                    // Inside math mode — keep as-is
                    result.append(part)
                }
            }
            t = result.enumerated().map { i, part in
                i % 2 == 0 ? part : "$\(part)$"
            }.joined()
        }

        return t
    }

    private func containsLaTeXCommand(_ text: String) -> Bool {
        let commands = ["\\frac", "\\sqrt", "\\cdot", "\\times", "\\div",
                       "\\le", "\\ge", "\\neq", "\\approx", "\\infty",
                       "\\sum", "\\prod", "\\int", "\\lim", "\\log",
                       "\\sin", "\\cos", "\\tan", "\\binom", "\\overline",
                       "\\begin", "\\text", "\\quad", "\\ldots", "\\cdots"]
        return commands.contains { text.contains($0) }
    }

    private func wrapOrphanedLaTeX(in text: String) -> String {
        // Wrap the entire segment since it contains LaTeX
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return text }
        return "$\(text)$"
    }

    var body: some View {
        if hasLaTeX {
            LaTeX(processedText)
                .fontDesign(.serif)
        } else {
            Text(text)
        }
    }
}

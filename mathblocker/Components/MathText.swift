//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import LaTeXSwiftUI

/// Renders text that may contain LaTeX math expressions.
/// Detects `$...$`, `\[...\]`, `\(...\)`, and bare LaTeX commands
/// like `\frac`, `\sqrt`, `\cdot`. Falls back to plain Text when
/// no LaTeX is detected.
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
        text.contains("\\times")
    }

    /// Wraps bare LaTeX (no delimiters) in $...$ so LaTeXSwiftUI can render it.
    private var processedText: String {
        var t = text
        // If it has LaTeX commands but no delimiters, wrap the whole thing
        if !t.contains("$") && !t.contains("\\[") && !t.contains("\\(") {
            t = "$\(t)$"
        }
        return t
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

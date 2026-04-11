//
//  MathText.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI
import SwiftMath

/// Renders text that may contain LaTeX math expressions.
/// Splits the input into prose and math segments, rendering prose with
/// SwiftUI's `Text` and math with SwiftMath's `MTMathUILabel` (a CoreText
/// LaTeX renderer that handles the full subset we need).
struct MathText: View {
    let text: String
    var fontSize: CGFloat = 18

    var body: some View {
        let segments = parse(text)
        let hasDisplayMath = segments.contains { seg in
            if case .math(_, let display) = seg { return display }
            return false
        }

        if hasDisplayMath {
            // Display math is block-level: each display segment gets its own row,
            // with prose and inline math rendered as inline Text runs in between.
            blockLayout(segments: segments)
        } else {
            // All text + inline math: concatenate into a single Text so SwiftUI
            // flows and wraps naturally. Each math segment is rasterized to a
            // template-mode UIImage that inherits the Text foreground color.
            inlineText(segments: segments)
        }
    }

    /// Builds a single `Text` view by concatenating text runs with rasterized
    /// math images, letting SwiftUI wrap and align the result like normal text.
    private func inlineText(segments: [Segment]) -> Text {
        segments.reduce(Text("")) { acc, seg in
            switch seg {
            case .text(let str):
                return acc + Text(str)
            case .math(let latex, _):
                if let image = renderInlineMathImage(latex: latex) {
                    return acc + Text(Image(uiImage: image))
                }
                return acc + Text(verbatim: latex)
            }
        }
    }

    /// Block layout: groups consecutive prose/inline-math runs into a single
    /// inline `Text` and renders each display-math segment on its own line.
    @ViewBuilder
    private func blockLayout(segments: [Segment]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(groupForBlockLayout(segments).enumerated()), id: \.offset) { _, group in
                switch group {
                case .inlineRun(let runSegments):
                    inlineText(segments: runSegments)
                case .displayMath(let latex):
                    MathLabel(latex: latex, fontSize: fontSize, display: true)
                }
            }
        }
    }

    private enum BlockGroup {
        case inlineRun([Segment])     // consecutive text + inline math
        case displayMath(String)
    }

    private func groupForBlockLayout(_ segments: [Segment]) -> [BlockGroup] {
        var groups: [BlockGroup] = []
        var currentRun: [Segment] = []
        for seg in segments {
            switch seg {
            case .math(let latex, true):
                if !currentRun.isEmpty {
                    groups.append(.inlineRun(currentRun))
                    currentRun = []
                }
                groups.append(.displayMath(latex))
            case .text, .math(_, false):
                currentRun.append(seg)
            }
        }
        if !currentRun.isEmpty {
            groups.append(.inlineRun(currentRun))
        }
        return groups
    }

    /// Rasterizes an inline math expression to a UIImage sized to its
    /// intrinsic content. Returned in `.alwaysTemplate` mode so that SwiftUI
    /// `Text` colors it with the current foreground style.
    ///
    /// Latin Modern Math has smaller x-height than SF Pro at the same point
    /// size, so we render at `fontSize × 1.3` to visually match surrounding
    /// body text.
    @MainActor
    private func renderInlineMathImage(latex: String) -> UIImage? {
        let renderSize = fontSize * 1.3
        let label = MTMathUILabel()
        label.font = MTFontManager().latinModernFont(withSize: renderSize)
        label.fontSize = renderSize
        label.labelMode = .text
        label.textAlignment = .left
        label.contentInsets = MTEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        label.backgroundColor = .clear
        label.textColor = .black // placeholder; template rendering tints the result
        label.latex = latex

        let size = label.intrinsicContentSize
        guard size.width > 0, size.height > 0 else { return nil }

        label.bounds = CGRect(origin: .zero, size: size)
        label.layoutIfNeeded()

        let format = UIGraphicsImageRendererFormat.default()
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        // MTMathUILabel uses `layer.isGeometryFlipped = true`; `layer.render(in:)`
        // produces an upside-down result. Flip the context so the rasterized
        // output matches UIKit top-down convention.
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            label.layer.render(in: cg)
        }
        return image.withRenderingMode(.alwaysTemplate)
    }

    // MARK: - Parsing

    private enum Segment {
        case text(String)
        case math(String, display: Bool) // display = true for $$..$$ or \[..\]
    }

    /// Auto-wraps bare LaTeX fragments in `$..$` when the question author
    /// forgot to put them inside math delimiters. Preserves existing
    /// `$..$`, `$$..$$`, `\[..\]`, and `\(..\)` sections verbatim.
    ///
    /// Example: `let a_1, a_2, \dots be a sequence` becomes
    /// `let $a_1$, $a_2$, $\dots$ be a sequence`.
    private func autoWrapBareLatex(_ input: String) -> String {
        var result = ""
        var prose = ""
        var i = input.startIndex

        func flushProse() {
            if !prose.isEmpty {
                result += wrapLatexTokensInProse(prose)
                prose = ""
            }
        }

        while i < input.endIndex {
            let remaining = input[i...]

            // Preserve \[..\]
            if remaining.hasPrefix("\\[") {
                flushProse()
                if let endRange = input.range(of: "\\]", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    result += String(input[i..<endRange.upperBound])
                    i = endRange.upperBound
                    continue
                }
            }
            // Preserve \(..\)
            if remaining.hasPrefix("\\(") {
                flushProse()
                if let endRange = input.range(of: "\\)", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    result += String(input[i..<endRange.upperBound])
                    i = endRange.upperBound
                    continue
                }
            }
            // Preserve $$..$$
            if remaining.hasPrefix("$$") {
                flushProse()
                if let endRange = input.range(of: "$$", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    result += String(input[i..<endRange.upperBound])
                    i = endRange.upperBound
                    continue
                }
            }
            // Preserve $..$
            if input[i] == "$" {
                flushProse()
                let mathStart = input.index(after: i)
                if let endRange = input.range(of: "$", range: mathStart..<input.endIndex) {
                    let closingEnd = input.index(after: endRange.lowerBound)
                    result += String(input[i..<closingEnd])
                    i = closingEnd
                    continue
                }
            }

            prose.append(input[i])
            i = input.index(after: i)
        }

        flushProse()
        return result
    }

    /// Wraps LaTeX-looking tokens in a prose string with `$..$`.
    ///
    /// Alternation priority (first match wins):
    /// 1. `\left…\right` paired groups, captured as a single block so the
    ///    inner expression (which may contain fractions, subscripts, etc.)
    ///    is passed to SwiftMath intact.
    /// 2. `\frac` with shorthand or braced args: `\frac12`, `\frac1{2}`,
    ///    `\frac{1}2`, `\frac{1}{2}`. Without this, the general command
    ///    rule would match just `\frac` and wrap `$\frac$` which is broken.
    /// 3. General backslash commands with optional braced args: `\dots`,
    ///    `\cdot`, `\overline{...}`, `\text{...}`.
    /// 4. Subscripts: `a_1`, `x_{12}`, `a_1^2`.
    /// 5. Superscripts: `x^2`, `x^{12}`, `x^{2}_{1}`.
    ///
    /// Word-boundary prefixed on sub/sup to avoid matching `my_var`-style
    /// underscores. `\left…\right` uses `[^a-zA-Z]` after both keywords so
    /// it requires an actual delimiter (`(`, `[`, `|`, `\`, `)` etc).
    private func wrapLatexTokensInProse(_ prose: String) -> String {
        let pattern = #"\\left[^a-zA-Z].*?\\right[^a-zA-Z]?|\\frac(?:\d|\{[^}]*\})(?:\d|\{[^}]*\})|\\[a-zA-Z]+(?:\{[^}]*\})*|\b[a-zA-Z]_(?:\{[^}]*\}|[a-zA-Z0-9])(?:\^(?:\{[^}]*\}|[a-zA-Z0-9]))?|\b[a-zA-Z]\^(?:\{[^}]*\}|[a-zA-Z0-9])(?:_(?:\{[^}]*\}|[a-zA-Z0-9]))?"#
        return prose.replacingOccurrences(
            of: pattern,
            with: "\\$$0\\$",
            options: .regularExpression
        )
    }

    /// Rewrites LaTeX commands that SwiftMath 1.7.3 doesn't support to the closest
    /// supported equivalent. See backlog.md "LaTeX Rendering" for the full list.
    private func rewriteForSwiftMath(_ latex: String) -> String {
        var s = latex

        // Display-mode fraction variants all collapse to \frac. SwiftMath's
        // labelMode already picks the right size based on display/text.
        s = s.replacingOccurrences(of: "\\\\dfrac(?![a-zA-Z])", with: "\\\\frac", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\tfrac(?![a-zA-Z])", with: "\\\\frac", options: .regularExpression)
        s = s.replacingOccurrences(of: "\\\\cfrac(?![a-zA-Z])", with: "\\\\frac", options: .regularExpression)

        // AMS-style context-aware dots. SwiftMath only knows `\ldots`
        // (low dots) and `\cdots` (centered dots), not the amsmath
        // variants. Map based on the semantic intent of each command.
        s = s.replacingOccurrences(of: "\\\\dotsm(?![a-zA-Z])", with: "\\\\cdots", options: .regularExpression) // multiplication dots
        s = s.replacingOccurrences(of: "\\\\dotsb(?![a-zA-Z])", with: "\\\\cdots", options: .regularExpression) // binary-op dots
        s = s.replacingOccurrences(of: "\\\\dotsi(?![a-zA-Z])", with: "\\\\cdots", options: .regularExpression) // integral-chain dots
        s = s.replacingOccurrences(of: "\\\\dotsc(?![a-zA-Z])", with: "\\\\ldots", options: .regularExpression) // comma-list dots
        s = s.replacingOccurrences(of: "\\\\dotso(?![a-zA-Z])", with: "\\\\ldots", options: .regularExpression) // other dots
        s = s.replacingOccurrences(of: "\\\\dots(?![a-zA-Z])", with: "\\\\ldots", options: .regularExpression)  // generic dots

        // \pmod{arg} → (mod arg) — parenthetical modulo
        s = s.replacingOccurrences(
            of: "\\\\pmod\\s*\\{([^}]*)\\}",
            with: " (\\\\text{mod } $1)",
            options: .regularExpression
        )
        // \pmod arg (no braces, single token) → (mod arg)
        s = s.replacingOccurrences(
            of: "\\\\pmod\\s+([a-zA-Z0-9])",
            with: " (\\\\text{mod } $1)",
            options: .regularExpression
        )

        // Section sign \S → \text{§}. Negative lookahead excludes \Sigma etc.
        s = s.replacingOccurrences(
            of: "\\\\S(?![a-zA-Z])",
            with: "\\\\text{§}",
            options: .regularExpression
        )

        // \begin{array}{col-spec}…\end{array} → \begin{matrix}…\end{matrix}.
        // Lossy (drops column alignment) but matrix handles arbitrary column counts,
        // which aligned doesn't.
        s = s.replacingOccurrences(
            of: "\\\\begin\\{array\\}\\s*\\{[^}]*\\}",
            with: "\\\\begin{matrix}",
            options: .regularExpression
        )
        s = s.replacingOccurrences(
            of: "\\\\end\\{array\\}",
            with: "\\\\end{matrix}",
            options: .regularExpression
        )

        return s
    }

    /// Splits the input into alternating text and math segments.
    /// Recognizes `$..$`, `$$..$$`, `\[..\]`, and `\(..\)`.
    private func parse(_ input: String) -> [Segment] {
        // Pre-normalize: some MATH-dataset questions leave LaTeX fragments
        // outside delimiters (e.g. "let a_1, a_2, \dots be a sequence").
        // Auto-wrap those fragments in `$..$` so the walker below finds them.
        let input = autoWrapBareLatex(input)

        var segments: [Segment] = []
        var current = ""
        var i = input.startIndex

        while i < input.endIndex {
            let remaining = input[i...]

            // Display math \[..\]
            if remaining.hasPrefix("\\[") {
                if !current.isEmpty {
                    segments.append(.text(current))
                    current = ""
                }
                if let endRange = input.range(of: "\\]", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    let mathStart = input.index(i, offsetBy: 2)
                    let math = String(input[mathStart..<endRange.lowerBound])
                    segments.append(.math(rewriteForSwiftMath(math), display: true))
                    i = endRange.upperBound
                    continue
                }
            }

            // Inline math \(..\)
            if remaining.hasPrefix("\\(") {
                if !current.isEmpty {
                    segments.append(.text(current))
                    current = ""
                }
                if let endRange = input.range(of: "\\)", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    let mathStart = input.index(i, offsetBy: 2)
                    let math = String(input[mathStart..<endRange.lowerBound])
                    segments.append(.math(rewriteForSwiftMath(math), display: false))
                    i = endRange.upperBound
                    continue
                }
            }

            // Display math $$..$$
            if remaining.hasPrefix("$$") {
                if !current.isEmpty {
                    segments.append(.text(current))
                    current = ""
                }
                if let endRange = input.range(of: "$$", range: input.index(i, offsetBy: 2)..<input.endIndex) {
                    let mathStart = input.index(i, offsetBy: 2)
                    let math = String(input[mathStart..<endRange.lowerBound])
                    segments.append(.math(rewriteForSwiftMath(math), display: true))
                    i = endRange.upperBound
                    continue
                }
            }

            // Inline math $..$
            if input[i] == "$" {
                if !current.isEmpty {
                    segments.append(.text(current))
                    current = ""
                }
                let mathStart = input.index(after: i)
                if let endRange = input.range(of: "$", range: mathStart..<input.endIndex) {
                    let math = String(input[mathStart..<endRange.lowerBound])
                    segments.append(.math(rewriteForSwiftMath(math), display: false))
                    i = endRange.upperBound
                    continue
                }
            }

            current.append(input[i])
            i = input.index(after: i)
        }

        if !current.isEmpty {
            segments.append(.text(current))
        }

        return segments
    }
}

/// SwiftUI wrapper around SwiftMath's `MTMathUILabel`.
struct MathLabel: UIViewRepresentable {
    let latex: String
    let fontSize: CGFloat
    let display: Bool

    func makeUIView(context: Context) -> MTMathUILabel {
        let label = MTMathUILabel()
        let mathFont = MTFontManager().latinModernFont(withSize: fontSize)
        if mathFont == nil {
            print("MathLabel: failed to load latinModern font!")
        }
        label.font = mathFont
        label.fontSize = fontSize
        label.labelMode = display ? .display : .text
        label.textAlignment = .left
        label.contentInsets = MTEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        label.textColor = .label
        label.latex = latex
        if let err = label.error {
            print("MathLabel error for '\(latex)': \(err.localizedDescription)")
        }
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func updateUIView(_ uiView: MTMathUILabel, context: Context) {
        uiView.font = MTFontManager().latinModernFont(withSize: fontSize)
        uiView.fontSize = fontSize
        uiView.labelMode = display ? .display : .text
        uiView.latex = latex
        uiView.invalidateIntrinsicContentSize()
    }

    @MainActor
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTMathUILabel, context: Context) -> CGSize? {
        // MTMathUILabel doesn't override UIView.sizeThatFits — its real size
        // only flows through intrinsicContentSize, which calls the internal
        // _sizeThatFits(CGSizeZero) with a valid _mathList. Use that directly.
        let intrinsic = uiView.intrinsicContentSize
        let width: CGFloat
        if let proposedWidth = proposal.width, proposedWidth.isFinite {
            width = min(intrinsic.width, proposedWidth)
        } else {
            width = intrinsic.width
        }
        return CGSize(width: width, height: intrinsic.height)
    }
}

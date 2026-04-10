//
//  LaTeXTestView.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import SwiftUI

/// Debug screen that renders one sample question per LaTeX feature so we
/// can visually verify which commands work and which break.
/// Add to Settings via a navigation link during dev.
struct LaTeXTestView: View {
    private let samples: [(name: String, text: String)] = [
        ("\\frac (simple)", "$\\frac{1}{2}$ and $\\frac{a}{b}$"),
        ("\\frac (shorthand)", "$\\frac12$ shorthand"),
        ("\\frac with \\left\\lceil", "Evaluate $\\left\\lceil3\\left(6-\\frac12\\right)\\right\\rceil$."),
        ("\\lceil/\\rceil only", "$\\lceil x \\rceil$"),
        ("\\equiv only", "$a \\equiv b$"),
        ("\\pmod only", "$a \\pmod{n}$"),
        ("\\equiv with \\pmod", "$a \\equiv b \\pmod{n}$"),
        ("\\frac{}{}^{}", "$\\frac{a}{b}^{2}$"),
        ("Two braced subs", "$x^{2} + y^{3}$"),
        ("\\sqrt", "What is the degree of the polynomial $(4 +5x^3 +100 +2\\pi x^4 + \\sqrt{10}x^4 +9)$?"),
        ("\\overline", "Express $\\frac{0.\\overline{666}}{1.\\overline{333}}$ as a common fraction."),
        ("\\cdot", "Simplify $\\sqrt[3]{1+8} \\cdot \\sqrt[3]{1+\\sqrt[3]{8}}$."),
        ("\\le / \\ge", "$-2 \\le x \\le 2$ and $x \\ge 0$"),
        ("\\triangle", "Given that $\\triangle+q=59$ and $(\\triangle+q)+q=106$, what is the value of $\\triangle$?"),
        ("\\times", "If $F(a, b, c, d) = a^b + c \\times d$, compute $F(2, 3, 4, 11)$."),
        ("\\circ", "$m\\angle XOY = 90^{\\circ}$"),
        ("\\dots / \\ldots / \\cdots", "Sum: $1, 4, 7, 10, 13, \\ldots$. Also $\\frac{1}{3^1} + \\frac{2}{3^2} + \\cdots$"),
        ("\\angle", "Right triangle with $m\\angle XOY = 90^{\\circ}$"),
        ("\\log", "Evaluate $\\log_5 625$."),
        ("\\lfloor / \\rfloor", "$x\\cdot\\lfloor x\\rfloor=70$"),
        ("\\dfrac", "$\\dfrac{1}{2} + \\dfrac{1}{x} = \\dfrac{5}{6}$"),
        ("\\pmod", "$a\\equiv b^{-1}\\pmod n$"),
        ("\\omega", "Circle $\\omega$ with $\\overline{AB}$ as diameter"),
        ("\\pi", "$2\\pi x^4 + \\sqrt{10}x^4$"),
        ("\\theta", "$r(\\theta) = \\frac{1}{1-\\theta}$"),
        ("\\alpha / \\beta", "$\\frac{x-\\alpha}{x+\\beta} = \\frac{x^2-80x+1551}{x^2+57x-2970}$"),
        ("\\sum", "$\\sum_{i=1}^{4} x_i = 100$"),
        ("\\prod", "$\\prod_{k=1}^{45} \\csc^2(2k-1)^\\circ$"),
        ("\\sin / \\cos / \\tan", "$\\sin 510^\\circ$, $\\cos 270^\\circ$, $\\tan 3825^\\circ$"),
        ("\\binom", "$\\binom{26}{13}+\\binom{26}{n}=\\binom{27}{14}$"),
        ("\\text inside math", "$x-5 \\text{ if } -2 \\le x \\le 2$"),
        ("\\textbf", "Find a $\\textbf{positive}$ integer $n$"),
        ("env: align*", "\\begin{align*}\n3x+y&=a,\\\\\n2x+5y&=2a\n\\end{align*}"),
        ("env: array (cases)", "$\\begin{array}{cl} ax+3, &\\text{ if }x>2 \\\\ x-5 &\\text{ if } -2 \\le x \\le 2 \\end{array}$"),
        ("env: cases", "$\\begin{cases} x/2 & \\text{if even} \\\\ 3x+1 & \\text{if odd} \\end{cases}$"),
        ("env: aligned", "$\\begin{aligned} a^2 + b^2 &< 16 \\\\ a + b &> 0 \\end{aligned}$"),
        ("display \\[ \\]", "Compute \\[\\frac{1}{2} + \\frac{1}{3} + \\frac{1}{6}\\]"),
        ("$$ display $$", "$$x^2 + y^2 = z^2$$"),
        ("\\, spacing (should be space)", "$7 \\, \\S \\, 2$"),
        ("\\quad spacing", "$x = 1 \\quad y = 2$"),
        ("Greek letters", "$\\alpha + \\beta + \\gamma + \\delta + \\epsilon + \\zeta$"),
        ("Subscripts/superscripts", "$x_1^2 + x_2^3 + x_n^{n-1}$"),
        ("Subscripts simple", "$x_1$"),
        ("Sub with braces", "$x_{1}^{2}$"),
        ("Real hendrycks question", "Let $a_1 = 2$ and $a_2 = 3$. Compute $a_1^2 + a_2^2$."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(samples, id: \.name) { sample in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(sample.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        MathText(text: sample.text)
                            .font(.body)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.cardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .cardShadow()
                    }
                }
            }
            .padding()
        }
        .background { FrostedBackground() }
        .navigationTitle("LaTeX Test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LaTeXTestView()
    }
}

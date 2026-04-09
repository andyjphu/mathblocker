//
//  QuestionGenerator.swift
//  mathblocker
//
//  Created by Andy Phu on 4/9/26.
//

import Foundation

nonisolated struct QuestionGenerator {

    // MARK: - Public

    static func generate(difficulty: Int, count: Int = 5) -> [MathQuestion] {
        (0..<count).map { _ in generateOne(difficulty: difficulty) }
    }

    static func generateOne(difficulty: Int) -> MathQuestion {
        let generators: [() -> MathQuestion]
        switch difficulty {
        case 1:
            generators = [arithmetic, fractions, percentages, absoluteValue]
        case 2:
            generators = [linearEquation, inequality, systemOfEquations, quadraticFactoring]
        case 3:
            generators = [quadraticFormula, logarithm, sequenceQuestion, polynomialOps]
        case 4:
            generators = [distanceMidpoint, slopeIntercept, circleEquation, graphInterpretation]
        case 5:
            generators = [trigRatio, unitCircle, trigIdentity, lawOfSines]
        default:
            generators = [arithmetic, fractions, percentages]
        }
        return generators.randomElement()!()
    }

    // MARK: - Tier 1: Pre-Algebra

    private static func arithmetic() -> MathQuestion {
        let ops: [(String, (Int, Int) -> Int)] = [
            ("+", +), ("-", -), ("*", *)
        ]
        let (symbol, op) = ops.randomElement()!
        let a = Int.random(in: 2...25)
        let b = Int.random(in: 2...25)
        let answer = op(a, b)

        return makeQuestion(
            text: "What is \(a) \(symbol) \(b)?",
            answer: answer,
            difficulty: 1,
            topic: "Arithmetic"
        )
    }

    private static func fractions() -> MathQuestion {
        let num1 = Int.random(in: 1...9)
        let den1 = Int.random(in: 2...10)
        let num2 = Int.random(in: 1...9)
        let den2 = Int.random(in: 2...10)

        let resultNum = num1 * den2 + num2 * den1
        let resultDen = den1 * den2
        let g = gcd(abs(resultNum), resultDen)

        return MathQuestion(
            text: "What is \(num1)/\(den1) + \(num2)/\(den2)?",
            choices: generateFractionChoices(num: resultNum / g, den: resultDen / g),
            correctAnswerIndex: 0,
            difficulty: 1,
            topic: "Fractions"
        )
    }

    private static func percentages() -> MathQuestion {
        let percent = [10, 15, 20, 25, 30, 40, 50, 75].randomElement()!
        let whole = Int.random(in: 2...20) * 10
        let answer = whole * percent / 100

        return makeQuestion(
            text: "What is \(percent)% of \(whole)?",
            answer: answer,
            difficulty: 1,
            topic: "Percentages"
        )
    }

    private static func absoluteValue() -> MathQuestion {
        let a = Int.random(in: -20...(-1))
        let b = Int.random(in: 1...15)
        let answer = abs(a) + b

        return makeQuestion(
            text: "What is |\(a)| + \(b)?",
            answer: answer,
            difficulty: 1,
            topic: "Absolute Value"
        )
    }

    // MARK: - Tier 2: Elementary Algebra

    private static func linearEquation() -> MathQuestion {
        let x = Int.random(in: -10...10)
        let a = Int.random(in: 2...8)
        let b = Int.random(in: -15...15)
        let result = a * x + b

        return makeQuestion(
            text: "Solve for x: \(a)x + \(b) = \(result)",
            answer: x,
            difficulty: 2,
            topic: "Linear Equations"
        )
    }

    private static func inequality() -> MathQuestion {
        let a = Int.random(in: 2...6)
        let b = Int.random(in: 1...20)
        let threshold = a * Int.random(in: 1...8)
        let boundary = (threshold - b)

        let answer = boundary / a + (boundary % a != 0 && boundary > 0 ? 1 : 0)
        let text = "What is the smallest integer x such that \(a)x + \(b) >= \(threshold)?"

        return makeQuestion(
            text: text,
            answer: answer,
            difficulty: 2,
            topic: "Inequalities"
        )
    }

    private static func systemOfEquations() -> MathQuestion {
        let x = Int.random(in: 1...8)
        let y = Int.random(in: 1...8)
        let a1 = Int.random(in: 1...4)
        let b1 = Int.random(in: 1...4)
        let a2 = Int.random(in: 1...4)
        let b2 = Int.random(in: 1...4)

        guard a1 * b2 != a2 * b1 else { return systemOfEquations() }

        let c1 = a1 * x + b1 * y
        let c2 = a2 * x + b2 * y

        return makeQuestion(
            text: "If \(a1)x + \(b1)y = \(c1) and \(a2)x + \(b2)y = \(c2), what is x + y?",
            answer: x + y,
            difficulty: 2,
            topic: "Systems of Equations"
        )
    }

    private static func quadraticFactoring() -> MathQuestion {
        let r1 = Int.random(in: 1...8)
        let r2 = Int.random(in: 1...8)
        let b = -(r1 + r2)
        let c = r1 * r2
        let bStr = b >= 0 ? "+ \(b)" : "- \(abs(b))"
        let cStr = c >= 0 ? "+ \(c)" : "- \(abs(c))"

        return makeQuestion(
            text: "What is the larger root of x^2 \(bStr)x \(cStr) = 0?",
            answer: max(r1, r2),
            difficulty: 2,
            topic: "Quadratic Factoring"
        )
    }

    // MARK: - Tier 3: Intermediate Algebra

    private static func quadraticFormula() -> MathQuestion {
        let r1 = Int.random(in: -5...5)
        let r2 = Int.random(in: -5...5)
        let a = 1
        let b = -(r1 + r2)
        let c = r1 * r2

        let discriminant = b * b - 4 * a * c
        let text = "What is the discriminant of x^2 \(signed(b))x \(signed(c)) = 0?"

        return makeQuestion(
            text: text,
            answer: discriminant,
            difficulty: 3,
            topic: "Quadratic Formula"
        )
    }

    private static func logarithm() -> MathQuestion {
        let bases: [(Int, Int, Int)] = [
            (2, 8, 3), (2, 16, 4), (2, 32, 5), (2, 64, 6),
            (3, 9, 2), (3, 27, 3), (3, 81, 4),
            (5, 25, 2), (5, 125, 3),
            (10, 100, 2), (10, 1000, 3),
        ]
        let (base, arg, answer) = bases.randomElement()!

        return makeQuestion(
            text: "What is log base \(base) of \(arg)?",
            answer: answer,
            difficulty: 3,
            topic: "Logarithms"
        )
    }

    private static func sequenceQuestion() -> MathQuestion {
        let a1 = Int.random(in: 1...5)
        let d = Int.random(in: 2...6)
        let n = Int.random(in: 5...10)
        let answer = a1 + (n - 1) * d

        return makeQuestion(
            text: "An arithmetic sequence starts at \(a1) with common difference \(d). What is the \(ordinal(n)) term?",
            answer: answer,
            difficulty: 3,
            topic: "Sequences"
        )
    }

    private static func polynomialOps() -> MathQuestion {
        let a = Int.random(in: 1...5)
        let b = Int.random(in: 1...5)
        let c = Int.random(in: 1...5)
        let d = Int.random(in: 1...5)
        let sumA = a + c
        let _ = b + d

        return makeQuestion(
            text: "Simplify: (\(a)x + \(b)) + (\(c)x + \(d)). What is the coefficient of x?",
            answer: sumA,
            difficulty: 3,
            topic: "Polynomials"
        )
    }

    // MARK: - Tier 4: Coordinate Geometry

    private static func distanceMidpoint() -> MathQuestion {
        let x1 = Int.random(in: 0...8) * 2
        let x2 = Int.random(in: 0...8) * 2
        let midX = (x1 + x2) / 2

        return makeQuestion(
            text: "What is the x-coordinate of the midpoint of (\(x1), 0) and (\(x2), 0)?",
            answer: midX,
            difficulty: 4,
            topic: "Coordinate Geometry"
        )
    }

    private static func slopeIntercept() -> MathQuestion {
        let m = Int.random(in: -5...5)
        let b = Int.random(in: -10...10)
        let x = Int.random(in: 1...5)
        let y = m * x + b

        return makeQuestion(
            text: "A line has slope \(m) and y-intercept \(b). What is y when x = \(x)?",
            answer: y,
            difficulty: 4,
            topic: "Slope-Intercept"
        )
    }

    private static func circleEquation() -> MathQuestion {
        let r = Int.random(in: 1...8)
        let rSquared = r * r

        return makeQuestion(
            text: "A circle is defined by x^2 + y^2 = \(rSquared). What is its radius?",
            answer: r,
            difficulty: 4,
            topic: "Circle Equations"
        )
    }

    private static func graphInterpretation() -> MathQuestion {
        let m = Int.random(in: 1...5)
        let b = Int.random(in: 0...10)
        let x = Int.random(in: 1...6)

        return makeQuestion(
            text: "A line passes through (0, \(b)) and (\(x), \(m * x + b)). What is its slope?",
            answer: m,
            difficulty: 4,
            topic: "Graph Interpretation"
        )
    }

    // MARK: - Tier 5: Trigonometry

    private static func trigRatio() -> MathQuestion {
        let triples = [(3, 4, 5), (5, 12, 13), (8, 15, 17)]
        let (a, b, c) = triples.randomElement()!

        return makeQuestion(
            text: "In a right triangle with legs \(a) and \(b) and hypotenuse \(c), what is the hypotenuse?",
            answer: c,
            difficulty: 5,
            topic: "Trigonometry"
        )
    }

    private static func unitCircle() -> MathQuestion {
        let angles = [0, 30, 45, 60, 90, 180, 270, 360]
        let a1 = angles.randomElement()!
        let a2 = angles.filter { $0 != a1 }.randomElement()!
        let answer = a1 + a2

        return makeQuestion(
            text: "What is \(a1) degrees + \(a2) degrees?",
            answer: answer,
            difficulty: 5,
            topic: "Unit Circle"
        )
    }

    private static func trigIdentity() -> MathQuestion {
        let a = Int.random(in: 1...10)
        let sinSq = a
        let cosSq = 1
        let answer = sinSq + cosSq

        return makeQuestion(
            text: "If sin^2(x) = \(a)/\(a + 1), what is sin^2(x) + cos^2(x)?",
            answer: answer,
            difficulty: 5,
            topic: "Trig Identities"
        )
    }

    private static func lawOfSines() -> MathQuestion {
        let triples = [(3, 4, 5), (5, 12, 13), (6, 8, 10)]
        let (a, b, _) = triples.randomElement()!
        let perimeter = a + b + Int(sqrt(Double(a * a + b * b)).rounded())

        return makeQuestion(
            text: "A right triangle has legs \(a) and \(b). What is its perimeter?",
            answer: perimeter,
            difficulty: 5,
            topic: "Triangle Properties"
        )
    }

    // MARK: - Helpers

    private static func makeQuestion(text: String, answer: Int, difficulty: Int, topic: String) -> MathQuestion {
        var choices = [answer]
        while choices.count < 4 {
            let offset = Int.random(in: 1...max(5, abs(answer / 2) + 1)) * [1, -1].randomElement()!
            let wrong = answer + offset
            if !choices.contains(wrong) {
                choices.append(wrong)
            }
        }
        let shuffledChoices = choices.shuffled()
        let correctIndex = shuffledChoices.firstIndex(of: answer)!

        return MathQuestion(
            text: text,
            choices: shuffledChoices.map(String.init),
            correctAnswerIndex: correctIndex,
            difficulty: difficulty,
            topic: topic
        )
    }

    private static func generateFractionChoices(num: Int, den: Int) -> [String] {
        let correct = den == 1 ? "\(num)" : "\(num)/\(den)"
        var choices = [correct]
        while choices.count < 4 {
            let fakeNum = num + Int.random(in: -3...3)
            let fakeDen = max(1, den + Int.random(in: -2...2))
            let g = gcd(abs(fakeNum), fakeDen)
            let simplified = fakeDen / g == 1 ? "\(fakeNum / g)" : "\(fakeNum / g)/\(fakeDen / g)"
            if !choices.contains(simplified) && simplified != correct {
                choices.append(simplified)
            }
        }
        return choices.shuffled()
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        b == 0 ? a : gcd(b, a % b)
    }

    private static func signed(_ n: Int) -> String {
        n >= 0 ? "+ \(n)" : "- \(abs(n))"
    }

    private static func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

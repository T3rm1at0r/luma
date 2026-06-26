import Foundation

public enum MathRewriter {
    public static func rewrite(_ source: String) -> String {
        rewriteDelimited(source)
    }

    private static func rewriteDelimited(_ source: String) -> String {
        var out = ""
        out.reserveCapacity(source.count)
        let scalars = Array(source)
        var i = 0
        while i < scalars.count {
            if let span = matchDelimiter(scalars, at: i) {
                out += normalize(span.body)
                i = span.end
                continue
            }
            out.append(scalars[i])
            i += 1
        }
        return out
    }

    private struct DelimitedSpan {
        let body: String
        let end: Int
    }

    private static func matchDelimiter(_ scalars: [Character], at start: Int) -> DelimitedSpan? {
        for delimiter in delimiters {
            if let span = match(scalars, at: start, open: delimiter.open, close: delimiter.close) {
                return span
            }
        }
        return nil
    }

    private static let delimiters: [(open: [Character], close: [Character])] = [
        (["$", "$"], ["$", "$"]),
        (["$"], ["$"]),
        (["\\", "("], ["\\", ")"]),
        (["\\", "["], ["\\", "]"]),
    ]

    private static func match(
        _ scalars: [Character],
        at start: Int,
        open: [Character],
        close: [Character]
    ) -> DelimitedSpan? {
        guard hasSequence(scalars, at: start, sequence: open) else { return nil }
        if isEscaped(scalars, at: start) { return nil }
        var cursor = start + open.count
        var body = ""
        while cursor < scalars.count {
            if hasSequence(scalars, at: cursor, sequence: close) {
                return DelimitedSpan(body: body, end: cursor + close.count)
            }
            if scalars[cursor] == "\n" { return nil }
            body.append(scalars[cursor])
            cursor += 1
        }
        return nil
    }

    private static func hasSequence(_ scalars: [Character], at index: Int, sequence: [Character]) -> Bool {
        guard index + sequence.count <= scalars.count else { return false }
        for offset in 0..<sequence.count where scalars[index + offset] != sequence[offset] {
            return false
        }
        return true
    }

    private static func isEscaped(_ scalars: [Character], at index: Int) -> Bool {
        var slashes = 0
        var cursor = index - 1
        while cursor >= 0, scalars[cursor] == "\\" {
            slashes += 1
            cursor -= 1
        }
        return slashes % 2 == 1
    }

    private static func normalize(_ math: String) -> String {
        var text = math
        text = replaceFractions(text)
        text = replaceRoots(text)
        text = replaceCommands(text)
        text = replaceScripts(text)
        text = text.replacingOccurrences(of: "\\,", with: " ")
        text = text.replacingOccurrences(of: "\\quad", with: "  ")
        text = text.replacingOccurrences(of: "{", with: "")
        text = text.replacingOccurrences(of: "}", with: "")
        return text.trimmingCharacters(in: .whitespaces)
    }

    private static func replaceFractions(_ text: String) -> String {
        rewriteBracedPairs(text, command: "\\frac") { "\($0)/\($1)" }
    }

    private static func replaceRoots(_ text: String) -> String {
        rewriteBracedSingle(text, command: "\\sqrt") { "√\($0)" }
    }

    private static func replaceCommands(_ text: String) -> String {
        var result = text
        for (command, replacement) in symbolsByDescendingLength {
            result = result.replacingOccurrences(of: command, with: replacement)
        }
        return result
    }

    private static let symbolsByDescendingLength = symbols.sorted { $0.0.count > $1.0.count }

    private static func replaceScripts(_ text: String) -> String {
        var out = ""
        let scalars = Array(text)
        var i = 0
        while i < scalars.count {
            if scalars[i] == "^", i + 1 < scalars.count, let mapped = superscripts[scalars[i + 1]] {
                out.append(mapped)
                i += 2
                continue
            }
            if scalars[i] == "_", i + 1 < scalars.count, let mapped = subscripts[scalars[i + 1]] {
                out.append(mapped)
                i += 2
                continue
            }
            out.append(scalars[i])
            i += 1
        }
        return out
    }

    private static func rewriteBracedSingle(
        _ text: String,
        command: String,
        transform: (String) -> String
    ) -> String {
        var result = text
        while let range = result.range(of: command + "{") {
            guard let argEnd = matchingBrace(in: result, openBraceBefore: range.upperBound) else { break }
            let arg = String(result[range.upperBound..<argEnd])
            result.replaceSubrange(range.lowerBound..<result.index(after: argEnd), with: transform(arg))
        }
        return result
    }

    private static func rewriteBracedPairs(
        _ text: String,
        command: String,
        transform: (String, String) -> String
    ) -> String {
        var result = text
        while let range = result.range(of: command + "{") {
            guard let firstEnd = matchingBrace(in: result, openBraceBefore: range.upperBound),
                result.index(after: firstEnd) < result.endIndex,
                result[result.index(after: firstEnd)] == "{"
            else { break }
            let secondOpen = result.index(firstEnd, offsetBy: 2)
            guard let secondEnd = matchingBrace(in: result, openBraceBefore: secondOpen) else { break }
            let first = String(result[range.upperBound..<firstEnd])
            let second = String(result[secondOpen..<secondEnd])
            result.replaceSubrange(
                range.lowerBound..<result.index(after: secondEnd),
                with: transform(first, second)
            )
        }
        return result
    }

    private static func matchingBrace(in text: String, openBraceBefore start: String.Index) -> String.Index? {
        var depth = 1
        var cursor = start
        while cursor < text.endIndex {
            switch text[cursor] {
            case "{": depth += 1
            case "}":
                depth -= 1
                if depth == 0 { return cursor }
            default: break
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static let superscripts: [Character: Character] = [
        "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
        "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹",
        "+": "⁺", "-": "⁻", "n": "ⁿ", "i": "ⁱ",
    ]

    private static let subscripts: [Character: Character] = [
        "0": "₀", "1": "₁", "2": "₂", "3": "₃", "4": "₄",
        "5": "₅", "6": "₆", "7": "₇", "8": "₈", "9": "₉",
        "+": "₊", "-": "₋",
    ]

    private static let symbols: [(String, String)] = [
        ("\\alpha", "α"), ("\\beta", "β"), ("\\gamma", "γ"), ("\\delta", "δ"),
        ("\\epsilon", "ε"), ("\\zeta", "ζ"), ("\\eta", "η"), ("\\theta", "θ"),
        ("\\iota", "ι"), ("\\kappa", "κ"), ("\\lambda", "λ"), ("\\mu", "μ"),
        ("\\nu", "ν"), ("\\xi", "ξ"), ("\\pi", "π"), ("\\rho", "ρ"),
        ("\\sigma", "σ"), ("\\tau", "τ"), ("\\phi", "φ"), ("\\chi", "χ"),
        ("\\psi", "ψ"), ("\\omega", "ω"),
        ("\\Gamma", "Γ"), ("\\Delta", "Δ"), ("\\Theta", "Θ"), ("\\Lambda", "Λ"),
        ("\\Xi", "Ξ"), ("\\Pi", "Π"), ("\\Sigma", "Σ"), ("\\Phi", "Φ"),
        ("\\Psi", "Ψ"), ("\\Omega", "Ω"),
        ("\\Rightarrow", "⇒"), ("\\Leftarrow", "⇐"), ("\\Leftrightarrow", "⇔"),
        ("\\rightarrow", "→"), ("\\leftarrow", "←"), ("\\leftrightarrow", "↔"),
        ("\\to", "→"), ("\\mapsto", "↦"),
        ("\\leq", "≤"), ("\\geq", "≥"), ("\\neq", "≠"), ("\\approx", "≈"),
        ("\\equiv", "≡"), ("\\sim", "∼"), ("\\propto", "∝"),
        ("\\times", "×"), ("\\div", "÷"), ("\\pm", "±"), ("\\mp", "∓"),
        ("\\cdot", "·"), ("\\ast", "∗"), ("\\star", "⋆"),
        ("\\in", "∈"), ("\\notin", "∉"), ("\\subset", "⊂"), ("\\supset", "⊃"),
        ("\\subseteq", "⊆"), ("\\supseteq", "⊇"), ("\\cup", "∪"), ("\\cap", "∩"),
        ("\\emptyset", "∅"), ("\\forall", "∀"), ("\\exists", "∃"),
        ("\\infty", "∞"), ("\\partial", "∂"), ("\\nabla", "∇"),
        ("\\sum", "∑"), ("\\prod", "∏"), ("\\int", "∫"),
        ("\\sqrt", "√"), ("\\angle", "∠"), ("\\perp", "⊥"),
        ("\\mathbb{R}", "ℝ"), ("\\mathbb{C}", "ℂ"), ("\\mathbb{N}", "ℕ"),
        ("\\mathbb{Z}", "ℤ"), ("\\mathbb{Q}", "ℚ"),
        ("\\ldots", "…"), ("\\cdots", "⋯"), ("\\langle", "⟨"), ("\\rangle", "⟩"),
    ]
}

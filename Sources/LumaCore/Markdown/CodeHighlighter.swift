import Foundation

public enum CodeHighlighter {
    public static func highlight(_ code: String, language: String) -> StyledText {
        var spans: [StyledText.Span] = []
        var token = ""

        func flushToken() {
            guard !token.isEmpty else { return }
            spans.append(StyledText.Span(text: token, foreground: color(for: token)))
            token.removeAll(keepingCapacity: true)
        }

        for character in code {
            if character.isLetter || character.isNumber || character == "_" {
                token.append(character)
            } else {
                flushToken()
                spans.append(StyledText.Span(text: String(character), foreground: punctuationColor))
            }
        }
        flushToken()
        return StyledText(spans: spans)
    }

    private static func color(for token: String) -> RGBColor {
        if keywords.contains(token) { return keywordColor }
        if token.allSatisfy(\.isNumber) { return numberColor }
        return identifierColor
    }

    private static let keywordColor = RGBColor(r: 198, g: 120, b: 221)
    private static let numberColor = RGBColor(r: 209, g: 154, b: 102)
    private static let identifierColor = RGBColor(r: 171, g: 178, b: 191)
    private static let punctuationColor = RGBColor(r: 130, g: 137, b: 151)

    private static let keywords: Set<String> = [
        "actor", "as", "async", "await", "break", "case", "catch", "class", "const",
        "continue", "default", "defer", "do", "else", "enum", "export", "extends",
        "extension", "false", "final", "for", "func", "function", "guard", "if",
        "import", "in", "interface", "let", "new", "nil", "null", "private", "protocol",
        "public", "return", "self", "static", "struct", "super", "switch", "this",
        "throw", "throws", "true", "try", "type", "typeof", "var", "void", "while", "yield",
    ]
}

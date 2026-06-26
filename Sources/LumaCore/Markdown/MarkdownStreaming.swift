import Foundation

public enum MarkdownStreaming {
    public static func stablePrefix(of text: String) -> String {
        String(text[text.startIndex..<stableEnd(of: text)])
    }

    private static func stableEnd(of text: String) -> String.Index {
        var lineStart = text.startIndex
        var stableEnd = text.startIndex
        var insideCodeFence = false

        while lineStart < text.endIndex {
            var lineEnd = lineStart
            while lineEnd < text.endIndex, text[lineEnd] != "\n" {
                lineEnd = text.index(after: lineEnd)
            }
            let line = text[lineStart..<lineEnd].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                insideCodeFence.toggle()
            }
            let nextLineStart = lineEnd < text.endIndex ? text.index(after: lineEnd) : text.endIndex
            if !insideCodeFence, line.isEmpty {
                stableEnd = nextLineStart
            }
            lineStart = nextLineStart
        }
        return stableEnd
    }
}

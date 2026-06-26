import Foundation

public enum InlineMarkdownParser {
    public static func parse(_ raw: String) -> [InlineSpan] {
        var parser = Parser(text: MathRewriter.rewrite(raw))
        return parser.run()
    }

    private struct Parser {
        let chars: [Character]
        var index = 0
        var isBold = false
        var isItalic = false
        var isStrikethrough = false
        var buffer = ""
        var spans: [InlineSpan] = []

        init(text: String) {
            chars = Array(text)
        }

        mutating func run() -> [InlineSpan] {
            while index < chars.count {
                if consumeEscape() { continue }
                if consumeCodeSpan() { continue }
                if consumeLink() { continue }
                if consumeAutolink() { continue }
                if consumeBareURL() { continue }
                if consumeToken() { continue }
                if consumeEmphasis() { continue }
                buffer.append(chars[index])
                index += 1
            }
            flush()
            return spans
        }

        mutating func flush() {
            guard !buffer.isEmpty else { return }
            spans.append(
                InlineSpan(
                    text: buffer,
                    isBold: isBold,
                    isItalic: isItalic,
                    isStrikethrough: isStrikethrough
                )
            )
            buffer.removeAll(keepingCapacity: true)
        }

        mutating func consumeEscape() -> Bool {
            guard chars[index] == "\\", index + 1 < chars.count, chars[index + 1].isPunctuation else {
                return false
            }
            buffer.append(chars[index + 1])
            index += 2
            return true
        }

        mutating func consumeCodeSpan() -> Bool {
            guard chars[index] == "`" else { return false }
            var fence = 0
            while index + fence < chars.count, chars[index + fence] == "`" { fence += 1 }
            let bodyStart = index + fence
            var cursor = bodyStart
            while cursor < chars.count {
                if closingFence(at: cursor, length: fence) {
                    flush()
                    spans.append(InlineSpan(text: String(chars[bodyStart..<cursor]), isCode: true))
                    index = cursor + fence
                    return true
                }
                cursor += 1
            }
            return false
        }

        func closingFence(at position: Int, length: Int) -> Bool {
            guard position + length <= chars.count else { return false }
            for offset in 0..<length where chars[position + offset] != "`" {
                return false
            }
            let after = position + length
            return after == chars.count || chars[after] != "`"
        }

        mutating func consumeLink() -> Bool {
            guard chars[index] == "[", let label = matchBracketed(from: index, open: "[", close: "]") else {
                return false
            }
            let afterLabel = label.end
            guard afterLabel < chars.count, chars[afterLabel] == "(",
                let target = matchBracketed(from: afterLabel, open: "(", close: ")"),
                let url = URL(string: target.body.trimmingCharacters(in: .whitespaces))
            else { return false }
            flush()
            for var span in InlineMarkdownParser.parse(label.body) {
                span = InlineSpan(
                    text: span.text,
                    isBold: span.isBold,
                    isItalic: span.isItalic,
                    isCode: span.isCode,
                    isStrikethrough: span.isStrikethrough,
                    link: url
                )
                spans.append(span)
            }
            index = target.end
            return true
        }

        mutating func consumeAutolink() -> Bool {
            guard chars[index] == "<", let span = matchBracketed(from: index, open: "<", close: ">"),
                let url = URL(string: span.body), span.body.contains("://")
            else { return false }
            flush()
            spans.append(InlineSpan(text: span.body, link: url))
            index = span.end
            return true
        }

        mutating func consumeBareURL() -> Bool {
            guard atWordBoundary(before: index) else { return false }
            for scheme in ["https://", "http://"] where hasPrefix(scheme, at: index) {
                let end = urlEnd(from: index)
                let text = String(chars[index..<end])
                guard let url = URL(string: text) else { return false }
                flush()
                spans.append(InlineSpan(text: text, link: url))
                index = end
                return true
            }
            return false
        }

        mutating func consumeToken() -> Bool {
            let marker = chars[index]
            guard marker == "@" || marker == "#", atWordBoundary(before: index) else { return false }
            let bodyStart = index + 1
            guard bodyStart < chars.count, isTokenBody(chars[bodyStart]) else { return false }
            var cursor = bodyStart
            while cursor < chars.count, isTokenBody(chars[cursor]) { cursor += 1 }
            flush()
            spans.append(
                InlineSpan(text: String(chars[index..<cursor]), token: marker == "@" ? .mention : .hashtag)
            )
            index = cursor
            return true
        }

        mutating func consumeEmphasis() -> Bool {
            let marker = chars[index]
            guard marker == "*" || marker == "_" || marker == "~" else { return false }
            var length = 0
            while index + length < chars.count, chars[index + length] == marker { length += 1 }
            if marker == "~" {
                guard length >= 2 else { return false }
                return toggle(\.isStrikethrough, marker: marker, length: 2)
            }
            if length >= 2 {
                return toggle(\.isBold, marker: marker, length: 2)
            }
            return toggle(\.isItalic, marker: marker, length: 1)
        }

        mutating func toggle(_ flag: WritableKeyPath<Parser, Bool>, marker: Character, length: Int) -> Bool {
            if self[keyPath: flag] {
                guard closesEmphasis(marker: marker) else { return false }
                flush()
                self[keyPath: flag] = false
                index += length
                return true
            }
            guard opensEmphasis(marker: marker, length: length) else { return false }
            flush()
            self[keyPath: flag] = true
            index += length
            return true
        }

        func opensEmphasis(marker: Character, length: Int) -> Bool {
            let after = index + length
            guard after < chars.count, !chars[after].isWhitespace else { return false }
            guard marker == "_" else { return true }
            return atWordBoundary(before: index)
        }

        func closesEmphasis(marker: Character) -> Bool {
            guard index > 0, !chars[index - 1].isWhitespace else { return false }
            guard marker == "_" else { return true }
            let after = index + 1
            return after == chars.count || !isTokenBody(chars[after])
        }

        struct Bracketed {
            let body: String
            let end: Int
        }

        func matchBracketed(from start: Int, open: Character, close: Character) -> Bracketed? {
            guard chars[start] == open else { return nil }
            var depth = 1
            var cursor = start + 1
            var body = ""
            while cursor < chars.count {
                let ch = chars[cursor]
                if ch == open {
                    depth += 1
                } else if ch == close {
                    depth -= 1
                    if depth == 0 { return Bracketed(body: body, end: cursor + 1) }
                }
                body.append(ch)
                cursor += 1
            }
            return nil
        }

        func urlEnd(from start: Int) -> Int {
            var cursor = start
            while cursor < chars.count, !chars[cursor].isWhitespace { cursor += 1 }
            while cursor > start, ".,;:!?)]}".contains(chars[cursor - 1]) { cursor -= 1 }
            return cursor
        }

        func hasPrefix(_ prefix: String, at start: Int) -> Bool {
            let needle = Array(prefix)
            guard start + needle.count <= chars.count else { return false }
            for offset in 0..<needle.count where chars[start + offset] != needle[offset] {
                return false
            }
            return true
        }

        func atWordBoundary(before position: Int) -> Bool {
            guard position > 0 else { return true }
            return !isTokenBody(chars[position - 1])
        }

        func isTokenBody(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_" || character == "-"
        }
    }
}

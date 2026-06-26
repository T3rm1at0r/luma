import Foundation

public enum MarkdownParser {
    public static func parse(_ text: String) -> [MarkdownBlock] {
        var parser = Parser(text: text)
        return parser.run()
    }

    private struct Parser {
        let lines: [Substring]
        var index = 0
        var blocks: [MarkdownBlock] = []
        var textBuffer: [Substring] = []

        init(text: String) {
            lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        }

        mutating func run() -> [MarkdownBlock] {
            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if consumeCodeFence(trimmed) { continue }
                if consumeBlockquote(line) { continue }
                if consumeHeading(trimmed) { continue }
                if consumeHorizontalRule(trimmed) { continue }
                if consumeTaskList(trimmed) { continue }
                if consumeOrderedList(trimmed) { continue }
                if consumeBulletList(trimmed) { continue }
                if consumeFootnotes(trimmed) { continue }
                if consumeTable(trimmed) { continue }
                textBuffer.append(line)
                index += 1
            }
            flushText()
            return blocks
        }

        mutating func flushText() {
            let joined = textBuffer.joined(separator: "\n").trimmingCharacters(in: .newlines)
            textBuffer.removeAll()
            guard !joined.isEmpty else { return }
            blocks.append(.paragraph(InlineMarkdownParser.parse(joined)))
        }

        mutating func consumeCodeFence(_ trimmed: String) -> Bool {
            guard trimmed.hasPrefix("```") else { return false }
            flushText()
            let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var body: [Substring] = []
            index += 1
            while index < lines.count {
                let line = lines[index]
                if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    index += 1
                    break
                }
                body.append(line)
                index += 1
            }
            blocks.append(.code(language: language, code: body.joined(separator: "\n")))
            return true
        }

        mutating func consumeBlockquote(_ line: Substring) -> Bool {
            guard quotedContent(line) != nil else { return false }
            flushText()
            var inner: [String] = []
            while index < lines.count, let content = quotedContent(lines[index]) {
                inner.append(content)
                index += 1
            }
            blocks.append(.blockquote(MarkdownParser.parse(inner.joined(separator: "\n"))))
            return true
        }

        func quotedContent(_ line: Substring) -> String? {
            let trimmed = line.drop(while: { $0 == " " })
            guard trimmed.first == ">" else { return nil }
            let rest = trimmed.dropFirst()
            return rest.first == " " ? String(rest.dropFirst()) : String(rest)
        }

        mutating func consumeHeading(_ trimmed: String) -> Bool {
            guard trimmed.hasPrefix("#") else { return false }
            let level = trimmed.prefix(while: { $0 == "#" }).count
            guard (1...6).contains(level), trimmed.count > level else { return false }
            let separator = trimmed.index(trimmed.startIndex, offsetBy: level)
            guard trimmed[separator] == " " else { return false }
            let content = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { return false }
            flushText()
            blocks.append(.heading(level: level, content: InlineMarkdownParser.parse(content)))
            index += 1
            return true
        }

        mutating func consumeHorizontalRule(_ trimmed: String) -> Bool {
            let markers: Set<Character> = ["-", "_", "*"]
            guard let first = trimmed.first, markers.contains(first), trimmed.count >= 3,
                trimmed.allSatisfy({ $0 == first })
            else { return false }
            flushText()
            blocks.append(.horizontalRule)
            index += 1
            return true
        }

        mutating func consumeTaskList(_ trimmed: String) -> Bool {
            guard taskItem(trimmed) != nil else { return false }
            flushText()
            var items: [TaskListItem] = []
            while index < lines.count, let item = taskItem(lines[index].trimmingCharacters(in: .whitespaces)) {
                items.append(item)
                index += 1
            }
            blocks.append(.taskList(items))
            return true
        }

        func taskItem(_ trimmed: String) -> TaskListItem? {
            let bullets: Set<Character> = ["-", "*", "+"]
            guard let first = trimmed.first, bullets.contains(first), trimmed.count >= 5 else { return nil }
            let afterBullet = trimmed.dropFirst()
            guard afterBullet.hasPrefix(" [") else { return nil }
            let markIndex = afterBullet.index(afterBullet.startIndex, offsetBy: 2)
            let mark = afterBullet[markIndex]
            let afterMark = afterBullet.index(after: markIndex)
            guard afterBullet[afterMark...].hasPrefix("] ") else { return nil }
            let checked = mark == "x" || mark == "X"
            guard checked || mark == " " else { return nil }
            let content = afterBullet[afterBullet.index(afterMark, offsetBy: 2)...]
            return TaskListItem(isChecked: checked, content: InlineMarkdownParser.parse(String(content)))
        }

        mutating func consumeOrderedList(_ trimmed: String) -> Bool {
            guard orderedItem(trimmed) != nil else { return false }
            flushText()
            var items: [OrderedListItem] = []
            while index < lines.count, let item = orderedItem(lines[index].trimmingCharacters(in: .whitespaces)) {
                items.append(item)
                index += 1
            }
            blocks.append(.orderedList(items))
            return true
        }

        func orderedItem(_ trimmed: String) -> OrderedListItem? {
            let digits = trimmed.prefix(while: \.isNumber)
            guard !digits.isEmpty, let number = Int(digits) else { return nil }
            let afterDigits = trimmed[digits.endIndex...]
            guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")" else { return nil }
            let rest = afterDigits.dropFirst()
            guard rest.first == " " else { return nil }
            let content = rest.dropFirst()
            return OrderedListItem(
                number: number,
                delimiter: String(delimiter),
                content: InlineMarkdownParser.parse(String(content))
            )
        }

        mutating func consumeBulletList(_ trimmed: String) -> Bool {
            guard bulletItem(trimmed) != nil else { return false }
            flushText()
            var items: [[InlineSpan]] = []
            while index < lines.count, let item = bulletItem(lines[index].trimmingCharacters(in: .whitespaces)) {
                items.append(item)
                index += 1
            }
            blocks.append(.bulletList(items))
            return true
        }

        func bulletItem(_ trimmed: String) -> [InlineSpan]? {
            let bullets: Set<Character> = ["-", "*", "+"]
            guard let first = trimmed.first, bullets.contains(first), trimmed.dropFirst().first == " " else {
                return nil
            }
            return InlineMarkdownParser.parse(String(trimmed.dropFirst(2)))
        }

        mutating func consumeFootnotes(_ trimmed: String) -> Bool {
            guard footnote(trimmed) != nil else { return false }
            flushText()
            var items: [FootnoteItem] = []
            while index < lines.count, let item = footnote(lines[index].trimmingCharacters(in: .whitespaces)) {
                items.append(item)
                index += 1
            }
            blocks.append(.footnotes(items))
            return true
        }

        func footnote(_ trimmed: String) -> FootnoteItem? {
            guard trimmed.hasPrefix("[^"), let close = trimmed.range(of: "]:") else { return nil }
            let key = trimmed[trimmed.index(trimmed.startIndex, offsetBy: 2)..<close.lowerBound]
            guard !key.isEmpty else { return nil }
            let content = trimmed[close.upperBound...].trimmingCharacters(in: .whitespaces)
            return FootnoteItem(key: String(key), content: InlineMarkdownParser.parse(content))
        }

        mutating func consumeTable(_ trimmed: String) -> Bool {
            guard trimmed.contains("|"), index + 1 < lines.count,
                let alignments = tableAlignments(lines[index + 1].trimmingCharacters(in: .whitespaces))
            else { return false }
            let headers = splitRow(trimmed)
            guard headers.count == alignments.count, !headers.isEmpty else { return false }
            flushText()
            index += 2
            var rows: [[[InlineSpan]]] = []
            while index < lines.count {
                let rowTrimmed = lines[index].trimmingCharacters(in: .whitespaces)
                guard rowTrimmed.contains("|"), tableAlignments(rowTrimmed) == nil else { break }
                var cells = splitRow(rowTrimmed)
                while cells.count < headers.count { cells.append([]) }
                rows.append(Array(cells.prefix(headers.count)))
                index += 1
            }
            blocks.append(
                .table(MarkdownTable(headers: headers, rows: rows, alignments: alignments))
            )
            return true
        }

        func tableAlignments(_ trimmed: String) -> [ColumnAlignment]? {
            guard trimmed.contains("|"), trimmed.contains("-") else { return nil }
            let cells = splitRawRow(trimmed)
            guard !cells.isEmpty else { return nil }
            var alignments: [ColumnAlignment] = []
            for cell in cells {
                let spec = cell.trimmingCharacters(in: .whitespaces)
                guard spec.allSatisfy({ $0 == "-" || $0 == ":" }), spec.contains("-") else { return nil }
                let left = spec.hasPrefix(":")
                let right = spec.hasSuffix(":")
                alignments.append(left && right ? .center : right ? .trailing : .leading)
            }
            return alignments
        }

        func splitRow(_ trimmed: String) -> [[InlineSpan]] {
            splitRawRow(trimmed).map { InlineMarkdownParser.parse($0.trimmingCharacters(in: .whitespaces)) }
        }

        func splitRawRow(_ trimmed: String) -> [String] {
            var cells: [String] = []
            var current = ""
            var escaped = false
            var body = Substring(trimmed)
            if body.hasPrefix("|") { body = body.dropFirst() }
            if body.hasSuffix("|") { body = body.dropLast() }
            for ch in body {
                if escaped {
                    current.append(ch)
                    escaped = false
                } else if ch == "\\" {
                    escaped = true
                } else if ch == "|" {
                    cells.append(current)
                    current = ""
                } else {
                    current.append(ch)
                }
            }
            cells.append(current)
            return cells
        }
    }
}

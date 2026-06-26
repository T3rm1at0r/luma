import Foundation
import LumaCore

@MainActor
enum MissionMarkdown {
    static func pangoMarkup(from text: String) -> String {
        MarkdownParser.parse(text).map(flatten(_:)).joined(separator: "\n")
    }

    private static func flatten(_ block: MarkdownBlock) -> String {
        switch block {
        case .heading(let level, let content):
            return "<span size=\"\(level <= 2 ? "x-large" : "large")\" weight=\"bold\">\(InlineSpanPango.markup(for: content))</span>"
        case .paragraph(let content):
            return InlineSpanPango.markup(for: content)
        case .blockquote(let inner):
            return inner.map(flatten(_:)).joined(separator: "\n")
        case .horizontalRule:
            return "──────────"
        case .code(let language, let code):
            return StyledTextPango.markup(for: CodeHighlighter.highlight(code, language: language))
        case .table(let table):
            return flattenTable(table)
        case .bulletList(let items):
            return items.map { "• \(InlineSpanPango.markup(for: $0))" }.joined(separator: "\n")
        case .orderedList(let items):
            return items.map { "\($0.marker) \(InlineSpanPango.markup(for: $0.content))" }.joined(separator: "\n")
        case .taskList(let items):
            return items.map { "\($0.isChecked ? "☑" : "☐") \(InlineSpanPango.markup(for: $0.content))" }.joined(separator: "\n")
        case .footnotes(let items):
            return items.map { "\($0.key). \(InlineSpanPango.markup(for: $0.content))" }.joined(separator: "\n")
        }
    }

    private static func flattenTable(_ table: MarkdownTable) -> String {
        var lines = [table.headers.map { InlineSpanPango.markup(for: $0) }.joined(separator: "  |  ")]
        for row in table.rows {
            lines.append(row.map { InlineSpanPango.markup(for: $0) }.joined(separator: "  |  "))
        }
        return lines.joined(separator: "\n")
    }
}

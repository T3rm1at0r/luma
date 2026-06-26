import Foundation

public enum ColumnAlignment: Sendable, Hashable {
    case leading
    case center
    case trailing
}

public struct OrderedListItem: Sendable, Hashable {
    public let number: Int
    public let delimiter: String
    public let content: [InlineSpan]

    public init(number: Int, delimiter: String, content: [InlineSpan]) {
        self.number = number
        self.delimiter = delimiter
        self.content = content
    }

    public var marker: String { "\(number)\(delimiter)" }
}

public struct TaskListItem: Sendable, Hashable {
    public let isChecked: Bool
    public let content: [InlineSpan]

    public init(isChecked: Bool, content: [InlineSpan]) {
        self.isChecked = isChecked
        self.content = content
    }
}

public struct FootnoteItem: Sendable, Hashable {
    public let key: String
    public let content: [InlineSpan]

    public init(key: String, content: [InlineSpan]) {
        self.key = key
        self.content = content
    }
}

public struct MarkdownTable: Sendable, Hashable {
    public let headers: [[InlineSpan]]
    public let rows: [[[InlineSpan]]]
    public let alignments: [ColumnAlignment]

    public init(headers: [[InlineSpan]], rows: [[[InlineSpan]]], alignments: [ColumnAlignment]) {
        self.headers = headers
        self.rows = rows
        self.alignments = alignments
    }
}

public enum MarkdownBlock: Sendable, Hashable, Identifiable {
    case heading(level: Int, content: [InlineSpan])
    case paragraph([InlineSpan])
    case blockquote([MarkdownBlock])
    case horizontalRule
    case code(language: String, code: String)
    case table(MarkdownTable)
    case bulletList([[InlineSpan]])
    case orderedList([OrderedListItem])
    case taskList([TaskListItem])
    case footnotes([FootnoteItem])

    public var id: Int { hashValue }
}

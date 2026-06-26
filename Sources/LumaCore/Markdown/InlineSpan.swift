import Foundation

public struct InlineSpan: Sendable, Hashable {
    public enum Token: Sendable, Hashable {
        case mention
        case hashtag
    }

    public let text: String
    public let isBold: Bool
    public let isItalic: Bool
    public let isCode: Bool
    public let isStrikethrough: Bool
    public let link: URL?
    public let token: Token?

    public init(
        text: String,
        isBold: Bool = false,
        isItalic: Bool = false,
        isCode: Bool = false,
        isStrikethrough: Bool = false,
        link: URL? = nil,
        token: Token? = nil
    ) {
        self.text = text
        self.isBold = isBold
        self.isItalic = isItalic
        self.isCode = isCode
        self.isStrikethrough = isStrikethrough
        self.link = link
        self.token = token
    }
}

extension Array where Element == InlineSpan {
    public var plainText: String {
        map(\.text).joined()
    }
}

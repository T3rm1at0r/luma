import Foundation

public struct REPLCompletion: Sendable, Equatable {
    public let insertText: String
    public let displayText: String
    public let detailText: String?

    public init(insertText: String, displayText: String, detailText: String? = nil) {
        self.insertText = insertText
        self.displayText = displayText
        self.detailText = detailText
    }

    public init(_ text: String) {
        self.init(insertText: text, displayText: text)
    }
}

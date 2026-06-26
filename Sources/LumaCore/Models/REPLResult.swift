import Foundation

public struct REPLResult: Sendable {
    public let id: UUID
    public let code: String
    public let language: REPLLanguage
    public let value: Value
    public let timestamp: Date

    public enum Value: @unchecked Sendable {
        case js(JSInspectValue)
        case text(String)
        case styled(StyledText)
        case binary(Data, meta: REPLCell.Result.BinaryMeta?)
    }

    public init(id: UUID = UUID(), code: String, language: REPLLanguage = .javascript, value: Value, timestamp: Date = .now) {
        self.id = id
        self.code = code
        self.language = language
        self.value = value
        self.timestamp = timestamp
    }
}

import Foundation

public struct UserNotification: Sendable, Identifiable {
    public enum Severity: String, Sendable {
        case info
        case warning
        case error
    }

    public let id: UUID
    public let severity: Severity
    public let title: String
    public let message: String?
    public let timestamp: Date

    public init(
        id: UUID = UUID(),
        severity: Severity,
        title: String,
        message: String? = nil,
        timestamp: Date = .now
    ) {
        self.id = id
        self.severity = severity
        self.title = title
        self.message = message
        self.timestamp = timestamp
    }
}

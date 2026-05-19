import Foundation
import GRDB

public struct MemoryPage: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "memory_page"

    public static let pageSize: UInt64 = 0x1000
    public static let pageMask: UInt64 = pageSize &- 1

    public var sessionID: UUID
    public var pageAddress: UInt64
    public var bytes: Data
    public var capturedAt: Date

    public init(sessionID: UUID, pageAddress: UInt64, bytes: Data, capturedAt: Date = Date()) {
        self.sessionID = sessionID
        self.pageAddress = pageAddress
        self.bytes = bytes
        self.capturedAt = capturedAt
    }

    public static func pageBase(of address: UInt64) -> UInt64 {
        address & ~pageMask
    }

    public func encode(to container: inout PersistenceContainer) {
        container["session_id"] = sessionID.uuidString
        container["page_address"] = Int64(bitPattern: pageAddress)
        container["bytes"] = bytes
        container["captured_at"] = capturedAt
    }

    public init(row: Row) throws {
        guard let sidStr: String = row["session_id"], let sid = UUID(uuidString: sidStr) else {
            throw LumaCoreError.invalidArgument("memory_page: missing session_id")
        }
        sessionID = sid
        let raw: Int64 = row["page_address"]
        pageAddress = UInt64(bitPattern: raw)
        bytes = row["bytes"]
        capturedAt = row["captured_at"]
    }
}

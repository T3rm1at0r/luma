import Foundation
import GRDB

public struct ModuleAnalysis: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "module_analysis"

    public var sessionID: UUID
    public var moduleName: String
    public var moduleUUID: String?
    public var executableRanges: [Range]
    public var functions: [Function]
    public var aapDone: Bool
    public var analyzedAt: Date

    public enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case moduleName = "module_name"
        case moduleUUID = "module_uuid"
        case executableRanges = "executable_ranges"
        case functions
        case aapDone = "aap_done"
        case analyzedAt = "analyzed_at"
    }

    public init(
        sessionID: UUID,
        moduleName: String,
        moduleUUID: String? = nil,
        executableRanges: [Range],
        functions: [Function],
        aapDone: Bool,
        analyzedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.moduleName = moduleName
        self.moduleUUID = moduleUUID
        self.executableRanges = executableRanges
        self.functions = functions
        self.aapDone = aapDone
        self.analyzedAt = analyzedAt
    }

    public struct Range: Codable, Sendable, Hashable {
        public var offset: UInt64
        public var size: UInt64

        public init(offset: UInt64, size: UInt64) {
            self.offset = offset
            self.size = size
        }
    }

    public struct Function: Codable, Sendable, Hashable {
        public enum Source: String, Codable, Sendable {
            case exported
            case symbol
            case prelude
            case unwind
        }

        public var offset: UInt64
        public var name: String?
        public var source: Source

        public init(offset: UInt64, name: String?, source: Source) {
            self.offset = offset
            self.name = name
            self.source = source
        }
    }
}

extension ModuleAnalysis {
    public func encode(to container: inout PersistenceContainer) {
        container["session_id"] = sessionID.uuidString
        container["module_name"] = moduleName
        container["module_uuid"] = moduleUUID
        container["executable_ranges"] = try? JSONEncoder().encode(executableRanges)
        container["functions"] = try? JSONEncoder().encode(functions)
        container["aap_done"] = aapDone
        container["analyzed_at"] = analyzedAt
    }

    public init(row: Row) throws {
        guard let sidStr: String = row["session_id"], let sid = UUID(uuidString: sidStr) else {
            throw LumaCoreError.invalidArgument("module_analysis: missing session_id")
        }
        sessionID = sid
        moduleName = row["module_name"]
        moduleUUID = row["module_uuid"]
        let rangesData: Data = row["executable_ranges"]
        let functionsData: Data = row["functions"]
        executableRanges = (try? JSONDecoder().decode([Range].self, from: rangesData)) ?? []
        functions = (try? JSONDecoder().decode([Function].self, from: functionsData)) ?? []
        aapDone = row["aap_done"]
        analyzedAt = row["analyzed_at"]
    }
}

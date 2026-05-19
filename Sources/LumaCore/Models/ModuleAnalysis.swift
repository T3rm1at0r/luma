import Foundation
import GRDB

public struct ModuleAnalysis: Codable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "module_analysis"

    public var sessionID: UUID
    public var modulePath: String
    public var moduleUUID: String?
    public var mappedRanges: [ProcessNode.ModuleRange]
    public var functions: [Function]
    public var analyzedAt: Date

    public enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case modulePath = "module_path"
        case moduleUUID = "module_uuid"
        case mappedRanges = "mapped_ranges"
        case functions
        case analyzedAt = "analyzed_at"
    }

    public init(
        sessionID: UUID,
        modulePath: String,
        moduleUUID: String? = nil,
        mappedRanges: [ProcessNode.ModuleRange],
        functions: [Function],
        analyzedAt: Date = Date()
    ) {
        self.sessionID = sessionID
        self.modulePath = modulePath
        self.moduleUUID = moduleUUID
        self.mappedRanges = mappedRanges
        self.functions = functions
        self.analyzedAt = analyzedAt
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
    private static let wireEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let wireDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public func toWireJSON() -> [String: Any]? {
        guard let data = try? Self.wireEncoder.encode(self),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> ModuleAnalysis? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
            let analysis = try? wireDecoder.decode(ModuleAnalysis.self, from: data)
        else { return nil }
        return analysis
    }

    public func encode(to container: inout PersistenceContainer) {
        container["session_id"] = sessionID
        container["module_path"] = modulePath
        container["module_uuid"] = moduleUUID
        container["mapped_ranges"] = try? JSONEncoder().encode(mappedRanges)
        container["functions"] = try? JSONEncoder().encode(functions)
        container["analyzed_at"] = analyzedAt
    }

    public init(row: Row) throws {
        sessionID = row["session_id"]
        modulePath = row["module_path"]
        moduleUUID = row["module_uuid"]
        let rangesData: Data = row["mapped_ranges"]
        let functionsData: Data = row["functions"]
        mappedRanges = (try? JSONDecoder().decode([ProcessNode.ModuleRange].self, from: rangesData)) ?? []
        functions = (try? JSONDecoder().decode([Function].self, from: functionsData)) ?? []
        analyzedAt = row["analyzed_at"]
    }
}

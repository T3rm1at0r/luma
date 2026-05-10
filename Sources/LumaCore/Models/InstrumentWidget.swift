import Foundation

public struct InstrumentWidget: Codable, Identifiable, Sendable, Equatable {
    public var id: String
    public var name: String
    public var kind: Kind
    public var persistence: Persistence

    public init(id: String, name: String, kind: Kind, persistence: Persistence = .none) {
        self.id = id
        self.name = name
        self.kind = kind
        self.persistence = persistence
    }

    public enum Persistence: String, Codable, Sendable, CaseIterable {
        case none
        case session

        public var label: String {
            switch self {
            case .none: return "None"
            case .session: return "Session"
            }
        }
    }

    public enum Kind: Sendable, Equatable {
        case graph(GraphConfig)
        case list(ListConfig)
    }

    public struct GraphConfig: Codable, Sendable, Equatable {
        public static let defaultMaxPoints: Int = 5_000

        public var series: [Series]
        public var maxPoints: Int

        public init(series: [Series] = [], maxPoints: Int = Self.defaultMaxPoints) {
            self.series = series
            self.maxPoints = maxPoints
        }
    }

    public struct Series: Codable, Identifiable, Sendable, Equatable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    public struct ListConfig: Codable, Sendable, Equatable {
        public static let defaultMaxItems: Int = 1_000

        public var actions: [Action]
        public var maxItems: Int

        public init(actions: [Action] = [], maxItems: Int = Self.defaultMaxItems) {
            self.actions = actions
            self.maxItems = maxItems
        }
    }

    public struct Action: Codable, Identifiable, Sendable, Equatable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }
}

extension InstrumentWidget.Kind: Codable {
    private enum CodingKeys: String, CodingKey { case kind, config }
    private enum Tag: String, Codable { case graph, list }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Tag.self, forKey: .kind) {
        case .graph:
            self = .graph(try c.decode(InstrumentWidget.GraphConfig.self, forKey: .config))
        case .list:
            self = .list(try c.decode(InstrumentWidget.ListConfig.self, forKey: .config))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .graph(let g):
            try c.encode(Tag.graph, forKey: .kind)
            try c.encode(g, forKey: .config)
        case .list(let l):
            try c.encode(Tag.list, forKey: .kind)
            try c.encode(l, forKey: .config)
        }
    }
}

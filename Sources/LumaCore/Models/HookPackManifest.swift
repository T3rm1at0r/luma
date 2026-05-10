import Foundation

public struct HookPackManifest: Codable, Sendable, Equatable {
    public enum Icon: Codable, Sendable, Equatable {
        case symbolic(String)
        case file(String)

        private enum CodingKeys: String, CodingKey { case kind, value }
        private enum Kind: String, Codable { case symbolic, file }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            switch try c.decode(Kind.self, forKey: .kind) {
            case .symbolic: self = .symbolic(try c.decode(String.self, forKey: .value))
            case .file: self = .file(try c.decode(String.self, forKey: .value))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .symbolic(let id):
                try c.encode(Kind.symbolic, forKey: .kind)
                try c.encode(id, forKey: .value)
            case .file(let path):
                try c.encode(Kind.file, forKey: .kind)
                try c.encode(path, forKey: .value)
            }
        }
    }

    public var name: String
    public var icon: Icon?
    public var entry: String
    public var features: [CustomInstrumentDef.Feature]

    public init(
        name: String,
        icon: Icon?,
        entry: String,
        features: [CustomInstrumentDef.Feature]
    ) {
        self.name = name
        self.icon = icon
        self.entry = entry
        self.features = features
    }
}

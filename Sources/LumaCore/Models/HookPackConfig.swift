import Foundation

public struct HookPackConfig: Codable, Equatable, Sendable {
    public let packId: String
    public var features: [String: FeatureState]

    public init(packId: String, features: [String: FeatureState] = [:]) {
        self.packId = packId
        self.features = features
    }

    public static func decode(from data: Data) throws -> HookPackConfig {
        try JSONDecoder().decode(HookPackConfig.self, from: data)
    }

    public func encode() -> Data {
        try! JSONEncoder().encode(self)
    }

    public mutating func normalize(against features: [CustomInstrumentDef.Feature]) {
        var newFeatures: [String: FeatureState] = [:]
        for feature in features {
            if let existing = self.features[feature.id], existing.value.matches(schema: feature.schema) {
                newFeatures[feature.id] = existing
            } else {
                newFeatures[feature.id] = FeatureState(
                    enabled: feature.enabledByDefault,
                    value: feature.schema.defaultValue
                )
            }
        }
        self.features = newFeatures
    }

    public func normalized(against features: [CustomInstrumentDef.Feature]) -> HookPackConfig {
        var copy = self
        copy.normalize(against: features)
        return copy
    }

    public func toAgentJSON(features: [CustomInstrumentDef.Feature]) -> [String: Any] {
        let entries = features.compactMap { feature -> (String, Any)? in
            guard let state = self.features[feature.id] else { return nil }
            if feature.optional && !state.enabled { return nil }
            return (feature.id, state.value.toJSONNative())
        }
        return ["features": Dictionary(uniqueKeysWithValues: entries)]
    }
}

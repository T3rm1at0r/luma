public enum InstrumentStatus: Codable, Sendable, Hashable {
    case incompatible(reason: String)
    case loadFailed(message: String, stack: String?)
    case reloadFailed(message: String, stack: String?)
    case configInvalid(message: String, stack: String?)

    public var summary: String {
        switch self {
        case .incompatible(let reason):
            return reason
        case .loadFailed(let message, _),
            .reloadFailed(let message, _),
            .configInvalid(let message, _):
            return message
        }
    }

    public var stack: String? {
        switch self {
        case .incompatible:
            return nil
        case .loadFailed(_, let stack),
            .reloadFailed(_, let stack),
            .configInvalid(_, let stack):
            return stack
        }
    }

    public func toWireJSON() -> [String: Any] {
        switch self {
        case .incompatible(let reason):
            return ["kind": "incompatible", "reason": reason]
        case .loadFailed(let message, let stack):
            return wireFailure(kind: "load_failed", message: message, stack: stack)
        case .reloadFailed(let message, let stack):
            return wireFailure(kind: "reload_failed", message: message, stack: stack)
        case .configInvalid(let message, let stack):
            return wireFailure(kind: "config_invalid", message: message, stack: stack)
        }
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> InstrumentStatus? {
        guard let kind = obj["kind"] as? String else { return nil }
        switch kind {
        case "incompatible":
            guard let reason = obj["reason"] as? String else { return nil }
            return .incompatible(reason: reason)
        case "load_failed":
            guard let message = obj["message"] as? String else { return nil }
            return .loadFailed(message: message, stack: obj["stack"] as? String)
        case "reload_failed":
            guard let message = obj["message"] as? String else { return nil }
            return .reloadFailed(message: message, stack: obj["stack"] as? String)
        case "config_invalid":
            guard let message = obj["message"] as? String else { return nil }
            return .configInvalid(message: message, stack: obj["stack"] as? String)
        default:
            return nil
        }
    }

    private func wireFailure(kind: String, message: String, stack: String?) -> [String: Any] {
        var obj: [String: Any] = ["kind": kind, "message": message]
        if let stack { obj["stack"] = stack }
        return obj
    }
}

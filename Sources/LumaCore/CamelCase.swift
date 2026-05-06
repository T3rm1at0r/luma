import Foundation

public enum CamelCase {
    public static func sanitized(_ s: String) -> String {
        guard let first = s.first, first.isUppercase else { return s }
        return String(first).lowercased() + s.dropFirst()
    }

    public static func humanized(_ id: String) -> String {
        guard !id.isEmpty else { return "" }
        var parts: [String] = []
        var current = ""
        var prevLower = false
        for c in id {
            if c.isUppercase, prevLower, !current.isEmpty {
                parts.append(current)
                current = ""
            }
            current.append(c)
            prevLower = c.isLowercase
        }
        if !current.isEmpty {
            parts.append(current)
        }
        return parts.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
}

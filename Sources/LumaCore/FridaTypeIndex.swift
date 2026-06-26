import Foundation

enum FridaTypeIndex {
    static func detail(for member: String) -> String? {
        index[member]
    }

    private static let index: [String: String] = build()

    private static func build() -> [String: String] {
        var details: [String: String] = [:]
        var ambiguous: Set<String> = []
        for file in TypeScriptTypings.fridaGum {
            parse(file.content, into: &details, ambiguous: &ambiguous)
        }
        for name in ambiguous {
            details.removeValue(forKey: name)
        }
        return details
    }

    private static func parse(_ content: String, into details: inout [String: String], ambiguous: inout Set<String>) {
        var pendingDoc: String?
        var docSummary: String?
        var inDoc = false

        for rawLine in content.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if inDoc {
                if trimmed.contains("*/") {
                    inDoc = false
                    pendingDoc = docSummary
                } else if docSummary == nil {
                    let body = trimmed.drop(while: { $0 == "*" || $0 == " " }).trimmingCharacters(in: .whitespaces)
                    if !body.isEmpty, !body.hasPrefix("@") {
                        docSummary = body
                    }
                }
                continue
            }

            if trimmed.hasPrefix("/**") {
                docSummary = nil
                inDoc = !trimmed.contains("*/")
                if !inDoc {
                    pendingDoc = singleLineDoc(trimmed)
                }
                continue
            }

            if let (name, signature) = memberDeclaration(trimmed) {
                record(name: name, detail: pendingDoc ?? signature, into: &details, ambiguous: &ambiguous)
            }
            pendingDoc = nil
            docSummary = nil
        }
    }

    private static func record(name: String, detail: String, into details: inout [String: String], ambiguous: inout Set<String>) {
        guard !ambiguous.contains(name) else { return }
        if let existing = details[name] {
            if existing != detail {
                ambiguous.insert(name)
                details.removeValue(forKey: name)
            }
        } else {
            details[name] = detail
        }
    }

    private static func memberDeclaration(_ line: String) -> (name: String, detail: String)? {
        guard line.hasSuffix(";") else { return nil }

        if let match = functionPattern.firstCapture(in: line) {
            return (match.name, cleanSignature(match.rest))
        }
        if let match = memberPattern.firstCapture(in: line), !reservedNames.contains(match.name) {
            return (match.name, cleanSignature(match.rest))
        }
        return nil
    }

    private static func singleLineDoc(_ line: String) -> String? {
        guard let open = line.range(of: "/**"), let close = line.range(of: "*/") else { return nil }
        let inner = line[open.upperBound..<close.lowerBound]
            .trimmingCharacters(in: CharacterSet(charactersIn: " *"))
        return inner.isEmpty ? nil : inner
    }

    private static func cleanSignature(_ signature: String) -> String {
        var s = signature.trimmingCharacters(in: .whitespaces)
        if s.hasSuffix(";") { s.removeLast() }
        s = s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        if s.count > 120 {
            s = String(s.prefix(119)) + "…"
        }
        return s
    }

    private static let reservedNames: Set<String> = [
        "function", "interface", "namespace", "class", "type", "enum", "export",
        "declare", "import", "const", "let", "var", "extends", "implements",
        "return", "new", "typeof", "keyof", "readonly", "public", "private",
    ]

    private static let functionPattern = CapturePattern(
        #"^(?:export\s+)?(?:declare\s+)?function\s+([A-Za-z_$][\w$]*)\s*(\(.*)$"#
    )
    private static let memberPattern = CapturePattern(
        #"^(?:readonly\s+|static\s+|get\s+|set\s+|public\s+)?([A-Za-z_$][\w$]*)\??\s*([:(].*)$"#
    )
}

private struct CapturePattern {
    private let regex: NSRegularExpression?

    init(_ pattern: String) {
        regex = try? NSRegularExpression(pattern: pattern)
    }

    func firstCapture(in string: String) -> (name: String, rest: String)? {
        guard let regex,
            let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
            match.numberOfRanges >= 3,
            let nameRange = Range(match.range(at: 1), in: string),
            let restRange = Range(match.range(at: 2), in: string)
        else { return nil }
        return (String(string[nameRange]), String(string[restRange]))
    }
}

public enum CpuRegisterLayout {
    public struct Grid: Sendable {
        public let gpr: [[String]]
        public let vector: [[String]]
    }

    public static func arm64Grid(present: Set<String>, columnsPerRow: Int = 4) -> Grid? {
        guard present.contains("x0"), present.contains("nzcv") else { return nil }

        let gpr = arm64GPRRows.compactMap { row -> [String]? in
            let cells = row.filter(present.contains)
            return cells.isEmpty ? nil : cells
        }

        let vectorPrefix = present.contains("q0") ? "q" : "v"
        let vectorNames = ((0...31).map { "\(vectorPrefix)\($0)" }
            + (0...31).map { "d\($0)" }
            + (0...31).map { "s\($0)" }).filter(present.contains)
        let vector = stride(from: 0, to: vectorNames.count, by: columnsPerRow).map {
            Array(vectorNames[$0..<min($0 + columnsPerRow, vectorNames.count)])
        }

        return Grid(gpr: gpr, vector: vector)
    }

    public static func ordered(_ names: [String]) -> [String] {
        guard let grid = arm64Grid(present: Set(names)) else { return names }

        let sequence = grid.gpr.flatMap { $0 } + grid.vector.flatMap { $0 }
        let rank = Dictionary(uniqueKeysWithValues: sequence.enumerated().map { ($1, $0) })
        return names.enumerated().sorted { lhs, rhs in
            let lhsRank = rank[lhs.element] ?? sequence.count + lhs.offset
            let rhsRank = rank[rhs.element] ?? sequence.count + rhs.offset
            return lhsRank < rhsRank
        }.map(\.element)
    }

    private static let arm64GPRRows: [[String]] = [
        ["x0", "x1", "x2", "x3"],
        ["x4", "x5", "x6", "x7"],
        ["x8", "x9", "x10", "x11"],
        ["x12", "x13", "x14", "x15"],
        ["x16", "x17", "x18", "x19"],
        ["x20", "x21", "x22", "x23"],
        ["x24", "x25", "x26", "x27"],
        ["x28", "fp", "lr"],
        ["sp", "pc", "nzcv"],
    ]
}

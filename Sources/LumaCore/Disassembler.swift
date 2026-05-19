import Foundation
import SwiftyR2

public struct DisassemblyRequest: Sendable, Hashable {
    public let address: UInt64
    public let count: Int
    public let isDarkMode: Bool

    public init(address: UInt64, count: Int, isDarkMode: Bool) {
        self.address = address
        self.count = count
        self.isDarkMode = isDarkMode
    }
}

public enum DisassemblyScope: Sendable {
    case span
    case function
}

public struct DisassemblyPage: Sendable {
    public let lines: [DisassemblyLine]
    public let scope: DisassemblyScope

    public init(lines: [DisassemblyLine], scope: DisassemblyScope) {
        self.lines = lines
        self.scope = scope
    }
}

@MainActor
public final class Disassembler {
    private let node: ProcessNode
    private let sessionID: UUID
    private let processInfo: ProcessSession.ProcessInfo
    private let store: ProjectStore

    private var r2: R2Core!
    private var openTask: Task<Void, Never>?
    private var currentDarkMode: Bool?
    private var analyzedModules: Set<String> = []

    public init(node: ProcessNode, sessionID: UUID, processInfo: ProcessSession.ProcessInfo, store: ProjectStore) {
        self.node = node
        self.sessionID = sessionID
        self.processInfo = processInfo
        self.store = store
    }

    public func disassemble(_ request: DisassemblyRequest) async -> [DisassemblyLine] {
        await disassemblePage(request).lines
    }

    public func disassemblePage(_ request: DisassemblyRequest) async -> DisassemblyPage {
        await ensureOpened()
        if currentDarkMode != request.isDarkMode {
            await r2.applyTheme(request.isDarkMode ? "default" : "iaito")
            currentDarkMode = request.isDarkMode
        }
        let hex = String(request.address, radix: 16)
        if let module = node.modules.first(where: { request.address >= $0.base && request.address < ($0.base + $0.size) }) {
            await ensureModuleAnalyzed(module: module)
        }
        if let bounded = await disassembleFunctionIfStart(at: request.address, hex: hex) {
            return DisassemblyPage(lines: bounded, scope: .function)
        }
        let out = await r2.cmd("pdJ \(request.count) @ 0x\(hex)")
        return DisassemblyPage(lines: decodeOps(out), scope: .span)
    }

    private func disassembleFunctionIfStart(at address: UInt64, hex: String) async -> [DisassemblyLine]? {
        guard let begin = await fetchFunctionBegin(hex: hex), begin == address,
            let end = await fetchFunctionEnd(hex: hex), end > begin
        else { return nil }
        let bytes = end &- begin
        let out = await r2.cmd("pDJ \(bytes) @ 0x\(hex)")
        guard let ops = try? JSONDecoder().decode([R2DisasmOp].self, from: Data(out.utf8)) else {
            return nil
        }
        let lines = ops
            .filter { $0.isInstructionEntry }
            .map { $0.toDisassemblyLine() }
            .filter { $0.address < end }
        return lines.isEmpty ? nil : lines
    }

private func fetchFunctionEnd(hex: String) async -> UInt64? {
        let result = await r2.cmdWithLogs("?v $FE @ 0x\(hex)")
        if result.hasErrors { return nil }
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = parseHex(raw), value != 0 else { return nil }
        return value
    }

    private func decodeOps(_ raw: String) -> [DisassemblyLine] {
        guard let ops = try? JSONDecoder().decode([R2DisasmOp].self, from: Data(raw.utf8)) else {
            return []
        }
        return ops.filter { $0.isInstructionEntry }.map { $0.toDisassemblyLine() }
    }

    public func runCommand(_ command: String) async -> R2CommandResult {
        await ensureOpened()
        return await r2.cmdWithLogs(command)
    }

    public func findFunctionStart(containing address: UInt64) async -> UInt64? {
        await ensureOpened()
        if let module = node.modules.first(where: { address >= $0.base && address < ($0.base + $0.size) }) {
            await ensureModuleAnalyzed(module: module)
        }
        return await fetchFunctionBegin(hex: String(address, radix: 16))
    }

    private func ensureModuleAnalyzed(module: ProcessModule) async {
        if analyzedModules.contains(module.name) { return }
        analyzedModules.insert(module.name)

        let identity = try? await node.getModuleIdentity(name: module.name)

        if let existing = try? store.fetchModuleAnalysis(sessionID: sessionID, moduleName: module.name),
            existing.moduleUUID == identity
        {
            await replayAnalysis(existing, module: module)
            return
        }

        let ranges = (try? await node.enumerateModuleRanges(name: module.name)) ?? []
        let bundle = try? await node.enumerateModuleSymbols(name: module.name)

        let functions = await registerKnownFunctions(bundle: bundle, module: module)
        await runBoundedPreludeScan(ranges: ranges, module: module)

        let analysis = ModuleAnalysis(
            sessionID: sessionID,
            moduleName: module.name,
            moduleUUID: identity,
            executableRanges: ranges.map { .init(offset: $0.offset, size: $0.size) },
            functions: functions,
            aapDone: true
        )
        try? store.save(analysis)
    }

    private func replayAnalysis(_ analysis: ModuleAnalysis, module: ProcessModule) async {
        for function in analysis.functions {
            let addr = module.base &+ function.offset
            await defineFunction(at: addr, name: function.name)
        }
    }

    private func registerKnownFunctions(bundle: ModuleSymbolBundle?, module: ProcessModule) async -> [ModuleAnalysis.Function] {
        guard let bundle else { return [] }
        var result: [ModuleAnalysis.Function] = []
        var seenOffsets: Set<UInt64> = []
        let lo = module.base
        let hi = module.base &+ module.size

        for export in bundle.exports where export.kind == .function {
            guard export.address >= lo, export.address < hi else { continue }
            let offset = export.address &- lo
            await defineFunction(at: export.address, name: export.name)
            result.append(.init(offset: offset, name: export.name, source: .exported))
            seenOffsets.insert(offset)
        }
        for symbol in bundle.symbols where symbol.isCode {
            guard symbol.address >= lo, symbol.address < hi else { continue }
            let offset = symbol.address &- lo
            if seenOffsets.contains(offset) { continue }
            await defineFunction(at: symbol.address, name: symbol.name)
            result.append(.init(offset: offset, name: symbol.name, source: .symbol))
            seenOffsets.insert(offset)
        }
        return result
    }

    private func runBoundedPreludeScan(ranges: [ProcessNode.ModuleRange], module: ProcessModule) async {
        for range in ranges {
            let lo = module.base &+ range.offset
            let hi = lo &+ range.size
            _ = await r2.cmd("e search.from=0x\(String(lo, radix: 16))")
            _ = await r2.cmd("e search.to=0x\(String(hi, radix: 16))")
            _ = await r2.cmd("aap")
        }
    }

    private func defineFunction(at address: UInt64, name: String?) async {
        guard address != 0 else { return }
        let hex = String(address, radix: 16)
        if let name, !name.isEmpty {
            _ = await r2.cmd("af 0x\(hex) \(r2FlagSafe(name))")
        } else {
            _ = await r2.cmd("af 0x\(hex)")
        }
    }

    private func r2FlagSafe(_ name: String) -> String {
        name.map { c -> Character in
            if c.isLetter || c.isNumber || c == "_" || c == "." { return c }
            return "_"
        }.reduce(into: "") { $0.append($1) }
    }

    private func fetchFunctionBegin(hex: String) async -> UInt64? {
        let result = await r2.cmdWithLogs("?v $FB @ 0x\(hex)")
        if result.hasErrors { return nil }
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = parseHex(raw), value != 0 else { return nil }
        return value
    }

    private func parseHex(_ text: String) -> UInt64? {
        let lower = text.lowercased()
        if lower.hasPrefix("0x") {
            return UInt64(lower.dropFirst(2), radix: 16)
        }
        return UInt64(lower, radix: 16) ?? UInt64(lower)
    }

    public func decompile(at address: UInt64) async -> R2CommandResult {
        await ensureOpened()
        let hex = String(address, radix: 16)
        await r2.cmd("af @ 0x\(hex)")
        return await r2.cmdWithLogs("pdc @ 0x\(hex)")
    }

    private func ensureOpened() async {
        if let openTask {
            await openTask.value
            return
        }

        let task = Task { @MainActor in
            let r2 = await R2Core.create()
            self.r2 = r2

            await r2.registerIOPlugin(
                asyncProvider: ProcessMemoryIOProvider(node: node),
                uriSchemes: ["frida-mem://"]
            )

            await r2.setColorLimit(.mode16M)

            await r2.config.set("scr.utf8", bool: true)
            await r2.config.set("scr.color", colorMode: .mode16M)
            await r2.config.set("cfg.json.num", string: "hex")
            await r2.config.set("asm.emu", bool: true)
            await r2.config.set("emu.str", bool: true)
            await r2.config.set("anal.cc", string: "cdecl")

            await r2.config.set("asm.os", string: processInfo.platform)
            await r2.config.set("asm.arch", string: Self.r2Arch(fromFridaArch: processInfo.arch))
            await r2.config.set("asm.bits", int: processInfo.pointerSize * 8)

            let uri = "frida-mem://0x0"
            await r2.openFile(uri: uri)
            await r2.cmd("=!")
            await r2.binLoad(uri: uri)
        }

        openTask = task
        await task.value
    }

    public static func r2Arch(fromFridaArch arch: String) -> String {
        switch arch {
        case "ia32", "x64":
            return "x86"
        case "arm64":
            return "arm"
        default:
            return arch
        }
    }
}

private final class ProcessMemoryIOProvider: R2IOAsyncProvider, @unchecked Sendable {
    unowned let node: ProcessNode

    init(node: ProcessNode) {
        self.node = node
    }

    func supports(path: String, many: Bool) -> Bool {
        path.hasPrefix("frida-mem://")
    }

    func open(path: String, access: R2IOAccess, mode: Int32) async throws -> R2IOAsyncFile {
        guard let req = FridaMemURI.parse(path) else {
            throw NSError(domain: "LumaCore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid frida-mem URI"])
        }
        return ProcessMemoryIOFile(node: node, baseAddress: req.baseAddress)
    }
}

private final class ProcessMemoryIOFile: R2IOAsyncFile, @unchecked Sendable {
    private unowned let node: ProcessNode
    private let baseAddress: UInt64

    init(node: ProcessNode, baseAddress: UInt64) {
        self.node = node
        self.baseAddress = baseAddress
    }

    func close() async throws {}

    func read(at offset: UInt64, count: Int) async throws -> [UInt8] {
        try await node.readRemoteMemory(at: baseAddress &+ offset, count: count)
    }

    func write(at offset: UInt64, bytes: [UInt8]) async throws -> Int { 0 }
    func size() async throws -> UInt64 { UInt64.max }
    func setSize(_ size: UInt64) async throws {}
}

private struct FridaMemURI {
    let baseAddress: UInt64

    nonisolated static func parse(_ uri: String) -> FridaMemURI? {
        guard let url = URL(string: uri), url.scheme == "frida-mem" else { return nil }
        let raw = url.host ?? ""
        guard raw.hasPrefix("0x"), let base = UInt64(raw.dropFirst(2), radix: 16) else { return nil }
        return FridaMemURI(baseAddress: base)
    }
}

private struct R2DisasmOp: Decodable {
    let addr: String
    let text: String
    let arrow: String?
    let call: String?

    var addrValue: UInt64 { UInt64(addr.dropFirst(2), radix: 16) ?? 0 }
    var arrowValue: UInt64? { arrow.flatMap { UInt64($0.dropFirst(2), radix: 16) } }
    var callValue: UInt64? { call.flatMap { UInt64($0.dropFirst(2), radix: 16) } }

    var isInstructionEntry: Bool {
        StyledText.parseAnsi(text).plainText.contains(addr)
    }

    func toDisassemblyLine() -> DisassemblyLine {
        let styled = StyledText.parseAnsi(text)
        let plain = styled.plainText

        let addrR = plain.range(of: addr) ?? plain.startIndex..<plain.startIndex
        let addrStart = plain.distance(from: plain.startIndex, to: addrR.lowerBound)
        let addrEnd = plain.distance(from: plain.startIndex, to: addrR.upperBound)

        let afterAddr = plain[addrR.upperBound...]
        let trimmedAfterAddr = afterAddr.drop(while: { $0 == " " || $0 == "\t" })
        let bytesStartInAfter = afterAddr.distance(from: afterAddr.startIndex, to: trimmedAfterAddr.startIndex)
        let bytesStart = addrEnd + bytesStartInAfter

        let bytesToken = trimmedAfterAddr.prefix { $0 != " " && $0 != "\t" }
        let bytesEnd = bytesStart + bytesToken.count

        var remStart = bytesEnd
        while remStart < plain.count {
            let idx = plain.index(plain.startIndex, offsetBy: remStart)
            if plain[idx] == " " || plain[idx] == "\t" { remStart += 1 } else { break }
        }
        let remainder = String(plain.dropFirst(remStart))

        let asmPlain: String
        let commentPlain: String?
        if let semi = remainder.firstIndex(of: ";") {
            asmPlain = remainder[..<semi].trimmingCharacters(in: .whitespaces)
            commentPlain = remainder[semi...].trimmingCharacters(in: .whitespaces)
        } else {
            asmPlain = remainder.trimmingCharacters(in: .whitespaces)
            commentPlain = nil
        }

        let asmOffsetInRem = remainder.range(of: asmPlain)?.lowerBound ?? remainder.startIndex
        let asmStart = remStart + remainder.distance(from: remainder.startIndex, to: asmOffsetInRem)
        let asmEnd = asmStart + asmPlain.count

        let commentSlice: StyledText?
        if let commentPlain, let cr = remainder.range(of: commentPlain) {
            let cStart = remStart + remainder.distance(from: remainder.startIndex, to: cr.lowerBound)
            let cEnd = cStart + commentPlain.count
            commentSlice = styled.slice(charRange: cStart..<cEnd)
        } else {
            commentSlice = nil
        }

        return DisassemblyLine(
            address: addrValue,
            branchTarget: arrowValue,
            callTarget: callValue,
            addressText: styled.slice(charRange: addrStart..<addrEnd),
            bytesText: styled.slice(charRange: bytesStart..<bytesEnd),
            asmText: styled.slice(charRange: asmStart..<asmEnd),
            commentText: commentSlice
        )
    }
}

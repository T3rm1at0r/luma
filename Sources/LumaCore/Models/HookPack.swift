import Foundation

public struct HookPack: Sendable {
    public let id: String
    public let manifest: HookPackManifest
    public let folderURL: URL

    public init(id: String, manifest: HookPackManifest, folderURL: URL) {
        self.id = id
        self.manifest = manifest
        self.folderURL = folderURL
    }

    public var entryURL: URL {
        folderURL.appendingPathComponent(manifest.entry)
    }

    public var resolvedIcon: InstrumentIcon {
        switch manifest.icon {
        case nil:
            return .symbolic("puzzle")
        case .symbolic(let name):
            return .symbolic(name)
        case .file(let path):
            let url = folderURL.appendingPathComponent(path)
            if let data = try? Data(contentsOf: url) {
                return .pixels(data)
            }
            return .symbolic("puzzle")
        }
    }
}

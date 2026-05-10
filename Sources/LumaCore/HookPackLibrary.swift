import Foundation
import Observation

@Observable
@MainActor
public final class HookPackLibrary {
    public private(set) var packs: [HookPack] = []

    private let directory: URL

    public init(directory: URL) {
        self.directory = directory
        reload()
    }

    public func reload() {
        packs = discover()
    }

    public func pack(withId id: String) -> HookPack? {
        packs.first { $0.id == id }
    }

    public func descriptors() -> [InstrumentDescriptor] {
        packs.map { pack in
            let packID = pack.id
            let icon = pack.resolvedIcon
            let displayName = pack.manifest.name
            let initialFeatures = Dictionary(
                uniqueKeysWithValues: pack.manifest.features.map {
                    ($0.id, FeatureState(enabled: $0.enabledByDefault, value: $0.schema.defaultValue))
                }
            )

            return InstrumentDescriptor(
                id: "hook-pack:\(packID)",
                kind: .hookPack,
                sourceIdentifier: packID,
                displayName: displayName,
                icon: icon,
                makeInitialConfigJSON: {
                    HookPackConfig(packId: packID, features: initialFeatures).encode()
                }
            )
        }
    }

    private func discover() -> [HookPack] {
        let fm = FileManager.default
        guard
            let contents = try? fm.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return []
        }

        var result: [HookPack] = []
        for url in contents {
            guard
                let rv = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                rv.isDirectory == true
            else { continue }

            let manifestURL = url.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL) else { continue }

            do {
                let manifest = try JSONDecoder().decode(HookPackManifest.self, from: data)
                let id = url.lastPathComponent
                result.append(HookPack(id: id, manifest: manifest, folderURL: url))
            } catch {
                print("Failed to decode hook-pack manifest at \(manifestURL): \(error)")
            }
        }

        return result
    }
}

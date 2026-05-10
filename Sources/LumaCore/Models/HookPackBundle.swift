import Foundation

public struct HookPackBundle: Sendable {
    public struct IconAttachment: Sendable {
        public let filename: String
        public let data: Data

        public init(filename: String, data: Data) {
            self.filename = filename
            self.data = data
        }
    }

    public let manifestData: Data
    public let entryFilename: String
    public let entrySource: String
    public let icon: IconAttachment?

    public init(
        manifestData: Data,
        entryFilename: String,
        entrySource: String,
        icon: IconAttachment?
    ) {
        self.manifestData = manifestData
        self.entryFilename = entryFilename
        self.entrySource = entrySource
        self.icon = icon
    }
}

import Foundation
import Frida

#if canImport(CoreGraphics)
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
#endif

public extension Icon {
    var pngData: Data? {
        switch self {
        case .png(let bytes):
            return Data(bytes)
        case .rgba:
            #if canImport(CoreGraphics)
            return encodeCGImageAsPNG(cgImage)
            #else
            return nil
            #endif
        }
    }
}

#if canImport(CoreGraphics)
private func encodeCGImageAsPNG(_ image: CGImage) -> Data? {
    let buffer = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        buffer as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { return nil }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return buffer as Data
}
#endif

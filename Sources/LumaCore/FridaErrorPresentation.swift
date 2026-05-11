import Foundation
import Frida

extension Frida.Error: @retroactive CustomStringConvertible {}
extension Frida.Error: @retroactive LocalizedError {
    public var errorDescription: String? { description }
}

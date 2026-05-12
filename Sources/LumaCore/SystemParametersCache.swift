import Foundation
import Frida

public actor SystemParametersCache {
    private var entries: [String: Task<SystemParameters?, Never>] = [:]

    public init() {}

    public func parameters(for device: Device) async -> SystemParameters? {
        let deviceID = device.id
        if let inflight = entries[deviceID] {
            return await inflight.value
        }
        let task = Task { () -> SystemParameters? in
            guard let raw = try? await device.querySystemParameters() else { return nil }
            return SystemParameters(raw: raw)
        }
        entries[deviceID] = task
        return await task.value
    }

    public func invalidate(deviceID: String) {
        entries[deviceID] = nil
    }

    public func retain(deviceIDs: Set<String>) {
        entries = entries.filter { deviceIDs.contains($0.key) }
    }
}

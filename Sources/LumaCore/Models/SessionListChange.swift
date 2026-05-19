import Foundation

public enum SessionListChange: Sendable {
    case sessionAdded(ProcessSession)
    case sessionUpdated(ProcessSession)
    case sessionRemoved(UUID)
    case instrumentAdded(InstrumentInstance)
    case instrumentUpdated(InstrumentInstance)
    case instrumentRemoved(id: UUID, sessionID: UUID)
    case insightAdded(AddressInsight)
    case insightUpdated(AddressInsight)
    case insightRemoved(id: UUID, sessionID: UUID)
    case traceUpdated(ITrace)
    case traceRemoved(id: UUID, sessionID: UUID)
    case descriptorsChanged
    case customInstrumentDefsChanged
}

import Foundation
import Frida
import GRDB

public struct ProcessSession: Codable, Identifiable, Sendable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "process_session"

    public var id: UUID
    public var kind: Kind
    public var host: CollaborationSession.UserInfo?
    public var deviceID: String
    public var deviceName: String
    public var processName: String
    public var iconPNGData: Data?

    public var phase: Phase
    public var armingState: ArmingState
    public var lastArmPattern: String?
    public var detachReason: SessionDetachReason
    public var lastError: String?

    public var createdAt: Date
    public var lastKnownPID: UInt
    public var lastAttachedAt: Date?

    public var processInfo: ProcessInfo?
    public var lastKnownModules: [ProcessModule]?
    public var lastKnownThreads: [ProcessThread]?

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case host
        case deviceID = "device_id"
        case deviceName = "device_name"
        case processName = "process_name"
        case iconPNGData = "icon_png_data"
        case phase
        case armingState = "arming_state"
        case lastArmPattern = "last_arm_pattern"
        case detachReason = "detach_reason"
        case lastError = "last_error"
        case createdAt = "created_at"
        case lastKnownPID = "last_known_pid"
        case lastAttachedAt = "last_attached_at"
        case processInfo = "process_info"
        case lastKnownModules = "last_known_modules"
        case lastKnownThreads = "last_known_threads"
    }

    public init(
        id: UUID = UUID(),
        kind: Kind,
        host: CollaborationSession.UserInfo? = nil,
        deviceID: String,
        deviceName: String,
        processName: String,
        lastKnownPID: UInt,
        armingState: ArmingState = .unarmed
    ) {
        self.id = id
        self.kind = kind
        self.host = host
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.processName = processName
        self.phase = .idle
        self.armingState = armingState
        self.detachReason = .applicationRequested
        self.createdAt = Date()
        self.lastKnownPID = lastKnownPID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        kind = try container.decode(Kind.self, forKey: .kind)
        host = try container.decodeIfPresent(CollaborationSession.UserInfo.self, forKey: .host)
        deviceID = try container.decode(String.self, forKey: .deviceID)
        deviceName = try container.decode(String.self, forKey: .deviceName)
        processName = try container.decode(String.self, forKey: .processName)
        iconPNGData = try container.decodeIfPresent(Data.self, forKey: .iconPNGData)
        phase = try container.decode(Phase.self, forKey: .phase)
        armingState = try container.decodeIfPresent(ArmingState.self, forKey: .armingState) ?? .unarmed
        lastArmPattern = try container.decodeIfPresent(String.self, forKey: .lastArmPattern)
        detachReason = try container.decode(SessionDetachReason.self, forKey: .detachReason)
        lastError = try container.decodeIfPresent(String.self, forKey: .lastError)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        lastKnownPID = try container.decode(UInt.self, forKey: .lastKnownPID)
        lastAttachedAt = try container.decodeIfPresent(Date.self, forKey: .lastAttachedAt)
        processInfo = try container.decodeIfPresent(ProcessInfo.self, forKey: .processInfo)
        lastKnownModules = try container.decodeIfPresent([ProcessModule].self, forKey: .lastKnownModules)
        lastKnownThreads = try container.decodeIfPresent([ProcessThread].self, forKey: .lastKnownThreads)
    }

    public struct ProcessInfo: Codable, Sendable {
        public let platform: String
        public let arch: String
        public let pointerSize: Int

        public init(platform: String, arch: String, pointerSize: Int) {
            self.platform = platform
            self.arch = arch
            self.pointerSize = pointerSize
        }
    }

    public enum Kind: Codable, Sendable {
        case spawn(SpawnConfig)
        case attach

        public var verbDisplayName: String {
            switch self {
            case .spawn: return "spawn"
            case .attach: return "attach"
            }
        }

        public var reestablishLabel: String {
            switch self {
            case .spawn: return "Re-Spawn"
            case .attach: return "Re-Attach"
            }
        }

        public var inProgressLabel: String {
            switch self {
            case .spawn: return "Spawning…"
            case .attach: return "Attaching…"
            }
        }

        private enum CodingKeys: String, CodingKey {
            case kind
            case config
        }

        private enum KindTag: String, Codable {
            case spawn
            case attach
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .spawn(let config):
                try container.encode(KindTag.spawn, forKey: .kind)
                try container.encode(config, forKey: .config)
            case .attach:
                try container.encode(KindTag.attach, forKey: .kind)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let tag = try container.decode(KindTag.self, forKey: .kind)
            switch tag {
            case .spawn:
                let config = try container.decode(SpawnConfig.self, forKey: .config)
                self = .spawn(config)
            case .attach:
                self = .attach
            }
        }
    }

    public enum Phase: Int, Codable, Sendable {
        case idle
        case attaching
        case awaitingInitialResume
        case attached
    }

    public enum ArmingState: Codable, Sendable, Equatable {
        case unarmed
        case armed(matchPattern: String, armedAt: Date)

        public var armedSince: Date? {
            if case .armed(_, let date) = self { return date }
            return nil
        }

        public var matchPattern: String? {
            if case .armed(let pattern, _) = self { return pattern }
            return nil
        }

        private enum CodingKeys: String, CodingKey {
            case state
            case matchPattern = "match_pattern"
            case armedAt = "armed_at"
        }

        private enum StateTag: String, Codable {
            case unarmed
            case armed
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .unarmed:
                try container.encode(StateTag.unarmed, forKey: .state)
            case .armed(let pattern, let date):
                try container.encode(StateTag.armed, forKey: .state)
                try container.encode(pattern, forKey: .matchPattern)
                try container.encode(date, forKey: .armedAt)
            }
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch try container.decode(StateTag.self, forKey: .state) {
            case .unarmed:
                self = .unarmed
            case .armed:
                let pattern = try container.decode(String.self, forKey: .matchPattern)
                let armedAt = try container.decode(Date.self, forKey: .armedAt)
                self = .armed(matchPattern: pattern, armedAt: armedAt)
            }
        }
    }
}

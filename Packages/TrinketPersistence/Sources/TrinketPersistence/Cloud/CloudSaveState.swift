import Foundation
import TrinketCore

enum CloudSaveError: Error, Equatable {
    case unavailable
    case accountChanged
    case conflict
    case unsupportedSave
    case missingHead
}

struct CloudSaveRevision: Codable, Equatable, Sendable {
    var id: String
    var clock: [String: UInt64]
    var snapshot: CloudSaveSnapshot

    func includes(_ other: [String: UInt64]) -> Bool {
        other.allSatisfy { clock[$0.key, default: 0] >= $0.value }
    }
}

struct CloudSaveHead: Codable, Equatable, Sendable {
    var formatVersion = 1
    var epoch: String
    var resetCount: UInt64
    var authoritySequence: UInt64
    var productionClockEstablished = false
    var revision: CloudSaveRevision
}

struct CloudSaveRequest: Codable, Equatable, Sendable {
    enum Action: Codable, Equatable, Sendable {
        case upload
        case reset
        case collect
        case upgrade(HomesteadNodeID, Int)
    }

    let id: String
    let action: Action
    let baseEpoch: String?
    let baseRevisionID: String?
    let authoritySequence: UInt64
    let revision: CloudSaveRevision
}

struct CloudSaveReceipt: Codable, Equatable, Sendable {
    enum Outcome: Codable, Equatable, Sendable {
        case synchronized
        case collected([HomesteadResource: Int])
        case upgraded
        case insufficientResources
        case notAvailable
        case progressChanged
    }

    let requestID: String
    let epoch: String
    let authoritySequence: UInt64
    let outcome: Outcome
    var acceptedLocalSnapshot = false
}

struct CloudSaveBackup: Codable, Equatable, Sendable {
    let id: String
    let epoch: String?
    let snapshot: CloudSaveSnapshot
}

struct CloudAccountState: Codable, Equatable, Sendable {
    var base: CloudSaveHead?
    var pending: CloudSaveRequest?
    var resetRequested = false
}

struct CloudAccountArchive: Codable, Equatable, Sendable {
    let snapshot: CloudSaveSnapshot
    let state: CloudAccountState
}

struct CloudDeviceState: Codable, Equatable, Sendable {
    var formatVersion = 1
    var deviceID = UUID().uuidString
    var counter: UInt64 = 0
    var activeAccountID: String?
    var hasLinkedAccount = false
    var account = CloudAccountState()
    var archives: [String: CloudAccountArchive] = [:]
    var guestBackup: CloudSaveSnapshot?

    /// Maximum retained per-account archives. Evicted oldest-first on insert
    /// via `archiving(_:for:)`.
    static let maxArchives = 5

    mutating func archiving(_ archive: CloudAccountArchive, for accountID: String) {
        archives[accountID] = archive
        guard archives.count > Self.maxArchives else { return }
        // Evict an arbitrary oldest key; archives carry no timestamps, so
        // bound growth without claiming recency.
        for key in archives.keys where key != accountID {
            archives.removeValue(forKey: key)
            if archives.count <= Self.maxArchives {
                break
            }
        }
    }

    static func decode(_ data: Data?) throws -> Self {
        guard let data else { return Self() }
        let value = try JSONDecoder().decode(Self.self, from: data)
        guard value.formatVersion == 1 else { throw CloudSaveError.unsupportedSave }
        return value
    }
}

struct CloudServerSave: Sendable {
    let head: CloudSaveHead
    let changeToken: Data
    let serverTime: Date
}

protocol CloudSaveTransport: Sendable {
    func accountID() async throws -> String?
    func fetchHead(accountID: String) async throws -> CloudServerSave?
    func refreshTime(accountID: String, head: CloudServerSave) async throws -> CloudServerSave
    func fetchReceipt(accountID: String, requestID: String) async throws -> CloudSaveReceipt?
    func commit(
        accountID: String,
        replacing: CloudServerSave?,
        head: CloudSaveHead,
        receipt: CloudSaveReceipt,
        backups: [CloudSaveBackup],
    ) async throws -> CloudServerSave
}
